import Foundation

private func handleSignal(_: Int32) {
    SandboxCleaner.terminate()
}

enum SandboxCleaner {

    static func cleanupActiveSandbox(in registry: SandboxRegistry = .shared) {
        registry.cleanup()
    }

    static func terminate(registry: SandboxRegistry = .shared, exit: (Int32) -> Void = { _exit($0) }) {
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
