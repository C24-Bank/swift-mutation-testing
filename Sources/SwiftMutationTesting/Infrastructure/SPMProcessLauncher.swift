import Foundation

struct SPMProcessLauncher: Sendable, ProcessLaunching {
    func launch(
        executableURL: URL,
        arguments: [String],
        workingDirectoryURL: URL,
        timeout: Double
    ) async throws -> Int32 {
        try await makeRunner().launch(
            executableURL: executableURL,
            arguments: arguments,
            workingDirectoryURL: workingDirectoryURL,
            timeout: timeout
        )
    }

    func launchCapturing(
        _ request: ProcessRequest
    ) async throws -> (exitCode: Int32, output: String) {
        try await makeRunner().launchCapturing(request)
    }

    static func terminate(
        pid: pid_t,
        escalation: TimeoutEscalation,
        kill: SystemCalls.Kill = Darwin.kill
    ) {
        guard pid > 0 else { return }

        escalation.arm(pid: pid, descendants: ProcessTree.descendants(of: pid))
        _ = kill(-pid, SIGTERM)
    }

    private func makeRunner() -> ProcessRunner {
        let escalation = TimeoutEscalation()

        return ProcessRunner(
            postTerminationCleanup: { pid in
                kill(-pid, SIGKILL)
                escalation.processTerminated()
            },
            onTimeout: { pid in
                Self.terminate(pid: pid, escalation: escalation)
            }
        )
    }
}
