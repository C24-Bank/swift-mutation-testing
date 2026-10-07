import Foundation

/// Discovers the mutants and writes them to a plan, without building.
struct PlanCommand: Command {
    let configuration: RunnerConfiguration
    let path: String

    func execute() async throws -> ExitCode {
        let start = Date()
        let plan = try await Planner().plan(for: configuration).plan
        guard !plan.mutants.isEmpty else { throw FileDiscoveryError.noMutants(for: configuration) }
        try PlanStore().write(plan, to: path)

        await ConsoleProgressReporter.announceDiscovery(
            mutantCount: plan.mutants.count,
            schematizableCount: plan.mutants.filter(\.schematizable).count,
            duration: Date().timeIntervalSince(start),
            unless: configuration.reporting.quiet
        )
        StandardOutput.write("  ✓ Plan: \(path) (\(plan.mutants.count) mutants in \(plan.files.count) files)")
        return .success
    }
}
