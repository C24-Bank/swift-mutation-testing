import Foundation

struct XcodeProcessLauncher: Sendable, ProcessLaunching {
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
        grace: Duration = .seconds(5),
        kill: @escaping SystemCalls.Kill = Darwin.kill
    ) {
        guard pid > 0 else { return }

        _ = kill(-pid, SIGTERM)
        Task {
            try? await Task.sleep(for: grace)
            _ = kill(-pid, SIGKILL)
        }
    }

    private func makeRunner() -> ProcessRunner {
        ProcessRunner(
            onTimeout: { pid in
                Self.terminate(pid: pid)
            }
        )
    }
}
