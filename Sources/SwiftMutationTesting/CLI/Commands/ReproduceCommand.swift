/// Runs one mutant, by fingerprint or id, keeping its sandbox and showing everything.
struct ReproduceCommand: Command {
    let options: ParsedArguments.PlanOptions
    let configuration: RunnerConfiguration
    let launcher: (any ProcessLaunching)?

    func execute() async throws -> ExitCode {
        // The parser refuses `reproduce` without a mutant, so the reference is always there.
        let reference = options.mutant ?? ""
        var configuration = configuration
        let plan: Plan
        if let path = options.path {
            (plan, configuration) = try configuration.applyingPlan(at: path)
        } else {
            plan = try await Planner().plan(for: configuration).plan
        }

        SandboxCleaner.clearLeftovers()

        let launcher = launcher ?? configuration.build.projectType.defaultLauncher
        return try await SleepInhibitor.preventingIdleSleep { [configuration] in
            try await Reproducer().reproduce(reference, plan: plan, configuration: configuration, launcher: launcher)
        }
    }
}
