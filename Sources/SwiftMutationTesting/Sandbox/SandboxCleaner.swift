import Foundation
import Synchronization

private let signalTarget = Mutex(SandboxCleaner.SignalTarget.process)

private func handleSignal(_: Int32) {
    signalTarget.withLock { SandboxCleaner.terminate(registry: $0.registry, exit: $0.exit) }
}

enum SandboxCleaner {

    struct SignalTarget: Sendable {
        static let process = SignalTarget(registry: .shared, exit: { _exit($0) })

        let registry: SandboxRegistry
        let exit: @Sendable (Int32) -> Void
    }

    static func withSignalTarget<T>(_ target: SignalTarget, _ body: () throws -> T) rethrows -> T {
        let previous = signalTarget.withLock { current in
            defer { current = target }
            return current
        }
        defer { signalTarget.withLock { $0 = previous } }
        return try body()
    }

    static func cleanupActiveSandbox(in registry: SandboxRegistry = .shared) {
        registry.cleanup()
    }

    static func terminate(
        registry: SandboxRegistry = .shared,
        exit: (Int32) -> Void = SignalTarget.process.exit
    ) {
        registry.cleanup()
        exit(1)
    }

    static func removeOrphaned(in directory: URL = SandboxName.directory) {
        guard
            let contents = try? FileManager.default.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: nil
            )
        else { return }

        for url in contents where url.lastPathComponent.hasPrefix(SandboxName.prefix) {
            guard !SandboxName.isOwnerAlive(of: url.lastPathComponent) else { continue }
            try? FileManager.default.removeItem(at: url)
        }
    }

    static func register(_ sandbox: Sandbox, in registry: SandboxRegistry = .shared) {
        registry.register(sandbox)
    }

    static func deregister(in registry: SandboxRegistry = .shared) {
        registry.deregister()
    }

    static func installSignalHandlers() {
        signal(SIGINT, handleSignal)
        signal(SIGTERM, handleSignal)
    }
}
