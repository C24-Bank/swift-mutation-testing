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

        return try await SleepInhibitor.preventingIdleSleep {
            try await runPipeline(configuration: configuration, launcher: launcher)
        }
    }

    /// Prints each mutated file's selected tests, from the index and `.xctestrun` of the last build.
    private static func printTestSelection(
        for input: RunnerInput,
        configuration: RunnerConfiguration,
        launcher: any ProcessLaunching
    ) async throws {
        let rootURL = URL(fileURLWithPath: configuration.projectPath)
        let derivedDataURL = rootURL.appendingPathComponent(".xmr-derived-data")
        guard
            let xctestrunURL = BuildStage.locateXctestrun(rootURL: rootURL, derivedDataURL: derivedDataURL),
            let plist = XCTestRunPlist(try Data(contentsOf: xctestrunURL))
        else {
            throw BuildError.xctestrunNotFound
        }

        let files = Set(input.mutants.map(\.filePath))
        let selection = try await TestSelectionLoader(launcher: launcher).load(
            derivedDataURL: derivedDataURL, plist: plist, sourceFiles: files
        )
        for file in files.sorted() {
            let tests = selection.tests(for: file, within: configuration.build.testTarget)
            print("selection: \(file): \(tests.joined(separator: ", "))")
        }
    }

    private static func runPipeline(
        configuration: RunnerConfiguration,
        launcher: (any ProcessLaunching)?
    ) async throws -> ExitCode {
        if configuration.build.inPlace {
            setenv("SMT_IN_PLACE", "1", 1)
        }
        if let testPlan = configuration.build.testPlan {
            setenv("SMT_TEST_PLAN", testPlan, 1)
        }

        var (input, discoveryDuration) = try await discover(configuration: configuration)

        if !configuration.filter.mutantIDs.isEmpty || configuration.filter.skipIncompatible {
            let wanted = Set(configuration.filter.mutantIDs)
            let skipped = configuration.filter.skipIncompatible ? input.mutants.filter { !$0.isSchematizable }.count : 0
            if skipped > 0, !configuration.reporting.quiet {
                print("  ✓ Skipped \(skipped) mutants that would each need their own build")
            }
            input = RunnerInput(
                projectPath: input.projectPath,
                projectType: input.projectType,
                timeout: input.timeout,
                concurrency: input.concurrency,
                noCache: input.noCache,
                schematizedFiles: input.schematizedFiles,
                supportFileContent: input.supportFileContent,
                mutants: input.mutants.filter {
                    (wanted.isEmpty || wanted.contains($0.id))
                        && (!configuration.filter.skipIncompatible || $0.isSchematizable)
                }
            )
        }

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

        if configuration.filter.discoverOnly {
            for mutant in input.mutants where !mutant.isSchematizable {
                print("incompatible: \(mutant.filePath):\(mutant.line): \(mutant.description)")
            }
            if configuration.filter.selectTests {
                try await printTestSelection(
                    for: input,
                    configuration: configuration,
                    launcher: launcher ?? defaultLauncher(for: configuration.build.projectType)
                )
            }
            return .success
        }

        let executionLauncher: any ProcessLaunching = launcher ?? defaultLauncher(for: configuration.build.projectType)

        SandboxCleaner.removeOrphaned()

        if configuration.build.cleanupSimulators {
            let removed = await SimulatorManager(launcher: executionLauncher).removeLeftoverClones()
            if removed > 0, !configuration.reporting.quiet {
                print("  ✓ Removed \(removed) leftover simulator clones")
            }
        }

        let start = Date()
        let results = try await MutantExecutor(configuration: configuration, launcher: executionLauncher).execute(input)
        let duration = Date().timeIntervalSince(start)

        let summary = RunnerSummary(results: results, totalDuration: duration)
        TextReporter(projectRoot: configuration.projectPath).report(summary)
        writeReports(summary, configuration: configuration)

        return .success
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
            diffBase: configuration.filter.diffBase,
            sonarPropertiesPath: configuration.filter.sonarPropertiesPath,
            excludeCoverageBlocks: configuration.filter.excludeCoverageBlocks,
            operators: configuration.filter.operators
        )
        let input = try await DiscoveryPipeline().run(input: discoveryInput)
        return (input, Date().timeIntervalSince(start))
    }

    static func writeReports(_ summary: RunnerSummary, configuration: RunnerConfiguration) {
        let hasReports =
            configuration.reporting.output != nil
            || configuration.reporting.htmlOutput != nil
            || configuration.reporting.sonarOutput != nil
            || configuration.reporting.summaryOutput != nil
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

        if let summaryOutput = configuration.reporting.summaryOutput {
            writeReport(label: "Summary", to: summaryOutput) {
                try SummaryReporter(
                    outputPath: summaryOutput,
                    projectRoot: URL(fileURLWithPath: configuration.projectPath).standardizedFileURL.path
                ).report(summary)
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
