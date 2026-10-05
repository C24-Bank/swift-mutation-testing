import Synchronization

/// What a `reproduce` run kept: the sandboxes the executors left in place instead of removing, so that the
/// reproducer can name exactly its own, whatever else the process is running.
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
    /// Removes the sandbox, unless the run reproduces a mutant: then it is kept and recorded.
    func release(keepingFor reproduction: Reproduction?) {
        if let reproduction {
            reproduction.keep(self)
        } else {
            try? cleanup()
        }
    }
}
