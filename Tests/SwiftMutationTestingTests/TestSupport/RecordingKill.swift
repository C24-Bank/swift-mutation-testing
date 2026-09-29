import Foundation

@testable import SwiftMutationTesting

struct SentSignal: Equatable {
    let pid: pid_t
    let signal: Int32
}

final class RecordingKill: @unchecked Sendable {
    private let lock = NSLock()
    private var sent: [SentSignal] = []

    var recorded: [SentSignal] {
        lock.lock()
        defer { lock.unlock() }
        return sent
    }

    var asKill: SystemCalls.Kill {
        { [self] pid, signal in
            lock.lock()
            sent.append(SentSignal(pid: pid, signal: signal))
            lock.unlock()
            return 0
        }
    }
}
