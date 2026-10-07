import Foundation

public struct SwiftMutationTesting {

    public static func main() async {
        SandboxCleaner.installSignalHandlers()
        exit(await run(args: Array(CommandLine.arguments.dropFirst())).rawValue)
    }

    static func run(args: [String], launcher: (any ProcessLaunching)? = nil) async -> ExitCode {
        do {
            return try await command(for: try CommandLineParser().parse(args), launcher: launcher).execute()
        } catch let error as UsageError {
            StandardError.write(error.message)
            return .error
        } catch {
            StandardError.write("Error: \(error.localizedDescription)")
            return .error
        }
    }

    static func command(for parsed: ParsedArguments, launcher: (any ProcessLaunching)?) throws -> any Command {
        switch parsed.command {
        case .help:
            return HelpCommand()

        case .version:
            return VersionCommand()

        case .initialize:
            return InitCommand(projectPath: parsed.projectPath, launcher: launcher ?? XcodeProcessLauncher())

        case .plan:
            return PlanCommand(configuration: try configuration(for: parsed), path: parsed.plan.path ?? "plan.json")

        case .merge:
            return MergeCommand(options: parsed.plan, configuration: try configuration(for: parsed))

        case .reproduce:
            return ReproduceCommand(
                options: parsed.plan, configuration: try configuration(for: parsed), launcher: launcher)

        case .run:
            return RunCommand(
                configuration: try configuration(for: parsed), planPath: parsed.plan.path, shard: parsed.plan.shard,
                launcher: launcher
            )
        }
    }

    // MARK: - Private

    private static func configuration(for parsed: ParsedArguments) throws -> RunnerConfiguration {
        let fileValues = try ConfigurationFileParser().parse(at: parsed.projectPath)
        return try ConfigurationResolver().resolve(cliArguments: parsed, fileValues: fileValues)
    }
}
