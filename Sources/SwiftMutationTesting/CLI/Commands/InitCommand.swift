struct InitCommand: Command {
    let projectPath: String
    let launcher: any ProcessLaunching

    func execute() async throws -> ExitCode {
        let detected = await ProjectDetector(launcher: launcher).detect(at: projectPath)
        try ConfigurationFileWriter().write(to: projectPath, project: detected)
        return .success
    }
}
