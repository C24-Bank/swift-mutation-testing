import Foundation

extension Planner {
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
    var defaultLauncher: any ProcessLaunching {
        switch self {
        case .xcode: XcodeProcessLauncher()
        case .spm: SPMProcessLauncher()
        }
    }
}

extension ConsoleProgressReporter {
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
    static func clearLeftovers() {
        OrphanedProcessReaper().reap()
        removeOrphaned()
    }
}
