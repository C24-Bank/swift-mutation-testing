struct VersionCommand: Command {
    func execute() async throws -> ExitCode {
        StandardOutput.write(Version.current)
        return .success
    }
}
