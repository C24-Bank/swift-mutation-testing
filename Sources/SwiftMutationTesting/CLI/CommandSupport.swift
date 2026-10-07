import Foundation

extension Planner {
    /// A plan of the configuration's sources, with the operators, test target and container it names.
    func plan(for configuration: RunnerConfiguration) async throws -> Planned {
        try await plan(
            input: DiscoveryInput(configuration), testTarget: configuration.build.testTarget,
            container: configuration.build.xcodeContainer
        )
    }
}

extension DiscoveryInput {
    init(_ configuration: RunnerConfiguration) {
        self.init(
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
}

extension PlanMaterializer.ExecutionOptions {
    init(_ configuration: RunnerConfiguration) {
        self.init(
            timeout: configuration.build.timeout,
            concurrency: configuration.build.concurrency,
            noCache: configuration.build.noCache
        )
    }
}

extension RunnerConfiguration {
    /// The plan at `path`, and this configuration under it.
    func applyingPlan(at path: String) throws -> (Plan, RunnerConfiguration) {
        let plan = try PlanStore().read(from: path)
        return (plan, try applying(plan))
    }
}

extension FileDiscoveryError {
    static func noMutants(for configuration: RunnerConfiguration) -> FileDiscoveryError {
        .noMutants(sourcesPath: configuration.filter.sourcesPath ?? configuration.projectPath)
    }
}

extension ProjectType {
    /// The launcher a run of this kind of project starts its processes with.
    var defaultLauncher: any ProcessLaunching {
        switch self {
        case .xcode: XcodeProcessLauncher()
        case .spm: SPMProcessLauncher()
        }
    }
}

extension ConsoleProgressReporter {
    /// The discovery line, unless the run is quiet.
    static func announceDiscovery(mutantCount: Int, schematizableCount: Int, duration: Double, unless quiet: Bool) async
    {
        guard !quiet else { return }
        await ConsoleProgressReporter().report(
            .discoveryFinished(
                mutantCount: mutantCount,
                schematizableCount: schematizableCount,
                incompatibleCount: mutantCount - schematizableCount,
                duration: duration
            ))
    }
}

extension SandboxCleaner {
    /// Kills the processes and removes the sandboxes an earlier run left behind.
    static func clearLeftovers() {
        OrphanedProcessReaper().reap()
        removeOrphaned()
    }
}
