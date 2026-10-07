/// One thing the tool was asked to do, with everything it needs to do it.
protocol Command: Sendable {
    func execute() async throws -> ExitCode
}
