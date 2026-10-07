import Foundation
import Synchronization

final class SandboxRegistry: Sendable {

    static let shared = SandboxRegistry()

    deinit {
        take()?.deallocate()
    }

    func register(_ sandbox: Sandbox) {
        guard !sandbox.isInPlace else { return }
        let path = sandbox.rootURL.path
        let buffer = UnsafeMutablePointer<CChar>.allocate(capacity: path.utf8.count + 1)
        _ = path.withCString { strcpy(buffer, $0) }
        let previous = active.exchange(Int(bitPattern: buffer), ordering: .acquiringAndReleasing)
        UnsafeMutablePointer<CChar>(bitPattern: previous)?.deallocate()
    }

    func deregister() {
        take()?.deallocate()
    }

    func cleanup() {
        guard let path = take() else { return }
        try? FileManager.default.removeItem(at: URL(fileURLWithPath: String(cString: path)))
        path.deallocate()
    }

    // MARK: - Private

    private let active = Atomic<Int>(0)

    private func take() -> UnsafeMutablePointer<CChar>? {
        UnsafeMutablePointer(bitPattern: active.exchange(0, ordering: .acquiringAndReleasing))
    }
}
