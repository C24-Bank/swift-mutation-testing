import Foundation

struct OrphanedProcessReaper: Sendable {
    var processes: @Sendable () -> [pid_t] = { ProcessTree.all() }
    var arguments: @Sendable (pid_t) -> [String]? = { ProcessArguments.read(pid: $0) }
    var descendants: @Sendable (pid_t) -> [pid_t] = { ProcessTree.descendants(of: $0) }
    var isOwnerAlive: @Sendable (String) -> Bool = { SandboxName.isOwnerAlive(of: $0) }
    var kill: SystemCalls.Kill = Darwin.kill

    @discardableResult
    func reap() -> [pid_t] {
        let current = getpid()
        var reaped: [pid_t] = []

        for pid in processes() where pid != current {
            guard
                let sandbox = Self.sandboxName(in: arguments(pid) ?? []),
                SandboxName.ownerPID(of: sandbox) != current,
                !isOwnerAlive(sandbox)
            else { continue }

            for descendant in descendants(pid) {
                _ = kill(descendant, SIGKILL)
            }
            _ = kill(pid, SIGKILL)
            reaped.append(pid)
        }

        return reaped
    }

    static func sandboxName(in arguments: [String]) -> String? {
        for argument in arguments {
            for component in argument.split(separator: "/") where SandboxName.ownerPID(of: String(component)) != nil {
                return String(component)
            }
        }
        return nil
    }
}
