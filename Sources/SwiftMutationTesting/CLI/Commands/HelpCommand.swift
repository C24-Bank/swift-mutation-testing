struct HelpCommand: Command {
    func execute() async throws -> ExitCode {
        StandardOutput.write(HelpText.usage)
        return .success
    }
}
