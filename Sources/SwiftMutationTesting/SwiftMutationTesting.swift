import Foundation

public struct SwiftMutationTesting {

    public static func main() async {
        SandboxCleaner.installSignalHandlers()
        exit(await run(args: Array(CommandLine.arguments.dropFirst())).rawValue)
    }

    static func run(args: [String], launcher: (any ProcessLaunching)? = nil) async -> ExitCode {
        do {
            return try await execute(args: args, launcher: launcher)
        } catch let error as UsageError {
            fputs(error.message + "\n", stderr)
            return .error
        } catch {
            fputs("Error: \(error.localizedDescription)\n", stderr)
            return .error
        }
    }

    private static func execute(args: [String], launcher: (any ProcessLaunching)?) async throws -> ExitCode {
        let parsed = try CommandLineParser().parse(args)

        if parsed.showHelp {
            StandardOutput.write(HelpText.usage)
            return .success
        }

        if parsed.showVersion {
            StandardOutput.write(Version.current)
            return .success
        }

        if parsed.showInit {
            let initLauncher = launcher ?? XcodeProcessLauncher()
            let detected = await ProjectDetector(launcher: initLauncher).detect(at: parsed.projectPath)
            try ConfigurationFileWriter().write(to: parsed.projectPath, project: detected)
            return .success
        }

        let fileValues = try ConfigurationFileParser().parse(at: parsed.projectPath)
        let configuration = try ConfigurationResolver().resolve(
            cliArguments: parsed,
            fileValues: fileValues
        )

        let baseline = try loadBaseline(for: configuration)

        return try await SleepInhibitor.preventingIdleSleep {
            try await runPipeline(configuration: configuration, baseline: baseline, launcher: launcher)
        }
    }

    private static func runPipeline(
        configuration: RunnerConfiguration,
        baseline: Baseline?,
        launcher: (any ProcessLaunching)?
    ) async throws -> ExitCode {
        let (input, discoveryDuration) = try await discover(configuration: configuration)

        if !configuration.reporting.quiet {
            let schematizable = input.mutants.filter { $0.isSchematizable }.count
            let incompatible = input.mutants.count - schematizable
            await ConsoleProgressReporter().report(
                .discoveryFinished(
                    mutantCount: input.mutants.count,
                    schematizableCount: schematizable,
                    incompatibleCount: incompatible,
                    duration: discoveryDuration
                ))
        }

        let executionLauncher: any ProcessLaunching = launcher ?? defaultLauncher(for: configuration.build.projectType)

        OrphanedProcessReaper().reap()
        SandboxCleaner.removeOrphaned()

        let start = Date()
        let results = try await MutantExecutor(configuration: configuration, launcher: executionLauncher).execute(input)
        let duration = Date().timeIntervalSince(start)

        let summary = RunnerSummary(results: results, totalDuration: duration)
        TextReporter(projectRoot: configuration.projectPath).report(summary)
        let gate = evaluateGate(summary, configuration: configuration, baseline: baseline)
        writeReports(summary, configuration: configuration, gate: gate)

        return try applyGate(gate, summary: summary, configuration: configuration)
    }

    static func loadBaseline(for configuration: RunnerConfiguration) throws -> Baseline? {
        guard let path = configuration.gate.baselinePath else { return nil }

        let baseline = try BaselineStore().read(from: path)
        let differences = BaselineScope(configuration: configuration).differences(from: baseline.scope)

        guard differences.isEmpty else {
            throw GateError.scopeMismatch(path: path, differences: differences)
        }

        return baseline
    }

    static func evaluateGate(
        _ summary: RunnerSummary,
        configuration: RunnerConfiguration,
        baseline: Baseline?
    ) -> GateResult? {
        guard configuration.gate.isActive else { return nil }
        return QualityGate().evaluate(summary, policy: configuration.gate.policy, baseline: baseline)
    }

    static func applyGate(
        _ gate: GateResult?,
        summary: RunnerSummary,
        configuration: RunnerConfiguration,
        now: Date = Date()
    ) throws -> ExitCode {
        var exitCode = ExitCode.success

        if let gate {
            GateReporter(projectRoot: configuration.projectPath).report(gate)
            if !gate.passed {
                exitCode = .gateFailed
            }
        }

        if let path = configuration.gate.writeBaselinePath {
            let written = Baseline(
                summary: summary,
                scope: BaselineScope(configuration: configuration),
                projectPath: configuration.projectPath,
                toolVersion: Version.number,
                createdAt: now
            )
            try BaselineStore().write(written, to: path)
            StandardOutput.write("")
            StandardOutput.write("  ✓ Baseline: \(path)")
        }

        return exitCode
    }

    private static func discover(configuration: RunnerConfiguration) async throws -> (RunnerInput, TimeInterval) {
        let start = Date()
        let discoveryInput = DiscoveryInput(
            projectPath: configuration.projectPath,
            projectType: configuration.build.projectType,
            timeout: configuration.build.timeout,
            concurrency: configuration.build.concurrency,
            noCache: configuration.build.noCache,
            sourcesPath: configuration.filter.sourcesPath ?? configuration.projectPath,
            excludePatterns: configuration.filter.excludePatterns,
            operators: configuration.filter.operators
        )
        let input = try await DiscoveryPipeline().run(input: discoveryInput)
        return (input, Date().timeIntervalSince(start))
    }

    static func writeReports(_ summary: RunnerSummary, configuration: RunnerConfiguration, gate: GateResult? = nil) {
        let reporting = configuration.reporting
        let hasReports = [
            reporting.output, reporting.htmlOutput, reporting.sonarOutput, reporting.sarifOutput,
            reporting.markdownOutput,
        ].contains { $0 != nil }
        guard hasReports else { return }
        StandardOutput.write("")

        if let output = configuration.reporting.output {
            writeReport(label: "JSON", to: output) {
                try JsonReporter(outputPath: output, projectRoot: configuration.projectPath).report(summary)
            }
        }

        if let htmlOutput = configuration.reporting.htmlOutput {
            writeReport(label: "HTML", to: htmlOutput) {
                try HtmlReporter(outputPath: htmlOutput, projectRoot: configuration.projectPath).report(summary)
            }
        }

        if let sonarOutput = configuration.reporting.sonarOutput {
            writeReport(label: "Sonar", to: sonarOutput) {
                try SonarReporter(outputPath: sonarOutput, projectRoot: configuration.projectPath).report(summary)
            }
        }

        if let sarifOutput = reporting.sarifOutput {
            writeReport(label: "SARIF", to: sarifOutput) {
                try SarifReporter(outputPath: sarifOutput, projectRoot: configuration.projectPath).report(summary)
            }
        }

        if let markdownOutput = reporting.markdownOutput {
            writeReport(label: "Markdown", to: markdownOutput) {
                try MarkdownReporter(outputPath: markdownOutput, projectRoot: configuration.projectPath)
                    .report(summary, gate: gate)
            }
        }
    }

    static func defaultLauncher(for projectType: ProjectType) -> any ProcessLaunching {
        switch projectType {
        case .xcode: XcodeProcessLauncher()
        case .spm: SPMProcessLauncher()
        }
    }

    private static func writeReport(label: String, to path: String, _ write: () throws -> Void) {
        do {
            try write()
            StandardOutput.write("  ✓ \(label) report: \(path)")
        } catch {
            fputs("Warning: could not write \(label) report to '\(path)': \(error.localizedDescription)\n", stderr)
        }
    }
}
