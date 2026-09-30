import Foundation
import Synchronization

final class ProcessGroupRegistry: @unchecked Sendable {

    static let shared = ProcessGroupRegistry()

    init(capacity: Int = 256) {
        self.capacity = capacity
        slots = .allocate(capacity: capacity)
        for index in 0 ..< capacity {
            (slots + index).initialize(to: Atomic(0))
        }
    }

    deinit {
        slots.deinitialize(count: capacity)
        slots.deallocate()
    }

    func register(_ pid: pid_t) {
        guard pid > 0 else { return }

        for index in 0 ..< capacity
        where slots[index].compareExchange(expected: 0, desired: pid, ordering: .acquiringAndReleasing).exchanged {
            return
        }
    }

    func deregister(_ pid: pid_t) {
        guard pid > 0 else { return }

        for index in 0 ..< capacity
        where slots[index].compareExchange(expected: pid, desired: 0, ordering: .acquiringAndReleasing).exchanged {
            return
        }
    }

    func killAll(kill: SystemCalls.Kill = Darwin.kill) {
        for index in 0 ..< capacity {
            let pid = slots[index].exchange(0, ordering: .acquiringAndReleasing)
            if pid > 0 {
                _ = kill(-pid, SIGKILL)
            }
        }
    }

    // MARK: - Private

    private let capacity: Int
    private let slots: UnsafeMutablePointer<Atomic<pid_t>>
}
