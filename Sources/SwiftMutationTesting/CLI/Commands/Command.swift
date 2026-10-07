protocol Command: Sendable {
    func execute() async throws -> ExitCode
}
