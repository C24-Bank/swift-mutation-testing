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
        var configuration = try ConfigurationResolver().resolve(
            cliArguments: parsed,
            fileValues: fileValues
        )

        switch parsed.command {
        case .plan:
            return try await writePlan(configuration: configuration, to: parsed.plan.path ?? "plan.json")

        case .merge:
            return try merge(parsed.plan, configuration: configuration)

        case .reproduce:
            return try await reproduce(parsed.plan, configuration: configuration, launcher: launcher)

        case .run:
            break
        }

        var planned: PlannedRun?
        if let path = parsed.plan.path {
            let plan = try PlanStore().read(from: path)
            configuration = try configuration.applying(plan)
            planned = PlannedRun(plan: plan, shard: parsed.plan.shard.flatMap(Shard.init(parsing:)))
        }

        let baseline = try loadBaseline(for: configuration)

        return try await SleepInhibitor.preventingIdleSleep {
            try await runPipeline(
                configuration: configuration, baseline: baseline, launcher: launcher, planned: planned
            )
        }
    }

    struct PlannedRun: Sendable {
        let plan: Plan
        let shard: Shard?
    }

    private static func runPipeline(
        configuration: RunnerConfiguration,
        baseline: Baseline?,
        launcher: (any ProcessLaunching)?,
        planned: PlannedRun? = nil
    ) async throws -> ExitCode {
        let discovered = try await discover(configuration: configuration, planned: planned)
        let (input, identity, discoveryDuration) = (discovered.input, discovered.identity, discovered.duration)

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

        if !discovered.resumed.isEmpty, !configuration.reporting.quiet {
            StandardOutput.write(
                "  ✓ Resumed \(discovered.resumed.count) verdicts from an interrupted run of this plan"
            )
        }

        let start = Date()
        var results = discovered.resumed
        // A run whose every mutant was resumed has nothing to build; any other run goes through the
        // executor, even with no mutant, as it always has.
        if !input.mutants.isEmpty || discovered.resumed.isEmpty {
            results += try await MutantExecutor(
                configuration: configuration, launcher: executionLauncher, planJournal: discovered.journal
            ).execute(input)
        }
        results.sort { Self.planIndex(of: $0.descriptor.id) < Self.planIndex(of: $1.descriptor.id) }
        if let journal = discovered.journal {
            PlanJournal.remove(at: journal.path)
        }
        let duration = Date().timeIntervalSince(start)

        let summary = RunnerSummary(results: results, totalDuration: duration)
        TextReporter(projectRoot: configuration.projectPath).report(summary)
        let gate = evaluateGate(summary, configuration: configuration, baseline: baseline)
        writeReports(summary, configuration: configuration, gate: gate, identity: identity)

        return try applyGate(gate, summary: summary, configuration: configuration)
    }

    private static func writePlan(configuration: RunnerConfiguration, to path: String) async throws -> ExitCode {
        let start = Date()
        let planned = try await Planner().plan(
            input: discoveryInput(for: configuration), testTarget: configuration.build.testTarget,
            container: configuration.build.xcodeContainer
        )
        try PlanStore().write(planned.plan, to: path)

        let plan = planned.plan
        if !configuration.reporting.quiet {
            let schematizable = plan.mutants.filter(\.schematizable).count
            await ConsoleProgressReporter().report(
                .discoveryFinished(
                    mutantCount: plan.mutants.count,
                    schematizableCount: schematizable,
                    incompatibleCount: plan.mutants.count - schematizable,
                    duration: Date().timeIntervalSince(start)
                ))
        }
        StandardOutput.write("  ✓ Plan: \(path) (\(plan.mutants.count) mutants in \(plan.files.count) files)")
        return .success
    }

    private static func merge(
        _ options: ParsedArguments.PlanOptions, configuration: RunnerConfiguration
    ) throws -> ExitCode {
        guard let planPath = options.path else {
            throw UsageError(message: "merge needs the plan the results ran: --plan <plan.json>")
        }
        let plan = try PlanStore().read(from: planPath)
        let configuration = try configuration.applying(plan)
        let baseline = try loadBaseline(for: configuration)

        let merged = try ResultMerger().merge(
            resultPaths: options.results, plan: plan, projectPath: configuration.projectPath
        )
        let summary = RunnerSummary(results: merged.results, totalDuration: merged.totalDuration)
        StandardOutput.write(
            "  ✓ Merged \(options.results.count) results of \(planPath): \(summary.results.count) mutants"
        )
        TextReporter(projectRoot: configuration.projectPath).report(summary)
        let gate = evaluateGate(summary, configuration: configuration, baseline: baseline)
        writeReports(
            summary, configuration: configuration, gate: gate,
            identity: RunIdentity(planSha256: try PlanStore.sha256(of: plan), shard: nil)
        )

        return try applyGate(gate, summary: summary, configuration: configuration)
    }

    private static func reproduce(
        _ options: ParsedArguments.PlanOptions, configuration: RunnerConfiguration, launcher: (any ProcessLaunching)?
    ) async throws -> ExitCode {
        guard let reference = options.mutant else {
            throw UsageError(
                message: "reproduce needs a mutant: a fingerprint or an id such as swift-mutation-testing_12")
        }

        var configuration = configuration
        let plan: Plan
        if let path = options.path {
            plan = try PlanStore().read(from: path)
            configuration = try configuration.applying(plan)
        } else {
            plan = try await Planner().plan(
                input: discoveryInput(for: configuration), testTarget: configuration.build.testTarget,
                container: configuration.build.xcodeContainer
            ).plan
        }

        OrphanedProcessReaper().reap()
        SandboxCleaner.removeOrphaned()

        return try await SleepInhibitor.preventingIdleSleep {
            try await Reproducer().reproduce(
                reference, plan: plan, configuration: configuration,
                launcher: launcher ?? defaultLauncher(for: configuration.build.projectType)
            )
        }
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

    struct Discovered {
        let input: RunnerInput
        let identity: RunIdentity
        let duration: TimeInterval
        /// Verdicts an interrupted run of the same plan and shard already reached; their mutants are not in
        /// `input`.
        var resumed: [ExecutionResult] = []
        var journal: PlanJournal?
    }

    private static func planIndex(of id: String) -> Int {
        Int(id.replacingOccurrences(of: "swift-mutation-testing_", with: "")) ?? 0
    }

    /// The run's input and identity: from the plan given, a slice of it under `--shard`, less what an
    /// interrupted run of it already reached, or from a plan made now and materialized at once, which is
    /// the plain run.
    private static func discover(
        configuration: RunnerConfiguration, planned: PlannedRun?
    ) async throws -> Discovered {
        let start = Date()
        let execution = PlanMaterializer.ExecutionOptions(
            timeout: configuration.build.timeout,
            concurrency: configuration.build.concurrency,
            noCache: configuration.build.noCache
        )

        if let planned {
            let plan = planned.plan
            let identity = RunIdentity(planSha256: try PlanStore.sha256(of: plan), shard: planned.shard)
            let journalPath = PlanJournal.path(
                projectPath: configuration.projectPath, planSha256: identity.planSha256, shard: planned.shard
            )
            let selection = planned.shard.map { ShardSelector.mutants(of: plan, in: $0) } ?? plan.mutants
            let journaled = PlanJournal.entries(at: journalPath)
            let remaining = selection.filter { journaled[$0.fingerprint] == nil }

            let input = try await PlanMaterializer().materialize(
                plan: plan, projectPath: configuration.projectPath, execution: execution, mutants: remaining
            )
            let resumed: [ExecutionResult] = plan.mutants.enumerated().compactMap { index, mutant in
                guard
                    let entry = journaled[mutant.fingerprint],
                    selection.contains(where: { $0.fingerprint == mutant.fingerprint })
                else { return nil }
                return ExecutionResult(
                    descriptor: PlanMaterializer.descriptor(
                        of: mutant, at: index, in: plan, projectPath: configuration.projectPath
                    ),
                    status: entry.status, testDuration: entry.duration, killerTestFile: entry.killerTestFile,
                    activated: entry.activated
                )
            }
            return Discovered(
                input: input, identity: identity, duration: Date().timeIntervalSince(start), resumed: resumed,
                journal: PlanJournal(path: journalPath, mutants: input.mutants)
            )
        }

        let made = try await Planner().plan(
            input: discoveryInput(for: configuration), testTarget: configuration.build.testTarget,
            container: configuration.build.xcodeContainer
        )
        let input = try PlanMaterializer().materialize(
            plan: made.plan, projectPath: configuration.projectPath, sources: made.sources, execution: execution
        )
        let identity = RunIdentity(planSha256: try PlanStore.sha256(of: made.plan), shard: nil)
        return Discovered(input: input, identity: identity, duration: Date().timeIntervalSince(start))
    }

    private static func discoveryInput(for configuration: RunnerConfiguration) -> DiscoveryInput {
        DiscoveryInput(
            projectPath: configuration.projectPath,
            projectType: configuration.build.projectType,
            timeout: configuration.build.timeout,
            concurrency: configuration.build.concurrency,
            noCache: configuration.build.noCache,
            sourcesPath: configuration.filter.sourcesPath ?? configuration.projectPath,
            excludePatterns: configuration.filter.excludePatterns,
            operators: configuration.filter.operators
        )
    }

    static func writeReports(
        _ summary: RunnerSummary, configuration: RunnerConfiguration, gate: GateResult? = nil,
        identity: RunIdentity? = nil
    ) {
        let reporting = configuration.reporting
        let hasReports = [
            reporting.output, reporting.htmlOutput, reporting.sonarOutput, reporting.sarifOutput,
            reporting.markdownOutput,
        ].contains { $0 != nil }
        guard hasReports else { return }
        StandardOutput.write("")

        if let output = configuration.reporting.output {
            writeReport(label: "JSON", to: output) {
                try JsonReporter(outputPath: output, projectRoot: configuration.projectPath)
                    .report(summary, identity: identity)
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
