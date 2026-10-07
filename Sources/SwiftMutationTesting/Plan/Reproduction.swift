import Synchronization

final class Reproduction: Sendable {
    private let sandboxes = Mutex<[String]>([])

    var keptSandboxes: [String] {
        sandboxes.withLock { $0 }
    }

    func keep(_ sandbox: Sandbox) {
        sandboxes.withLock { $0.append(sandbox.rootURL.path) }
    }
}

extension Sandbox {
    func release(keepingFor reproduction: Reproduction?) {
        if let reproduction {
            reproduction.keep(self)
        } else {
            try? cleanup()
        }
    }
}
