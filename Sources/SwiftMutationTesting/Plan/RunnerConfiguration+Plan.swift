extension RunnerConfiguration {
    /// The configuration a plan dictates: the project, the test target and the scope come from the plan,
    /// never from the command line or the file, so that the run measures exactly what was planned. The
    /// execution options — timeout, concurrency, cache, reports, gate — stay the caller's.
    func applying(_ plan: Plan) throws -> RunnerConfiguration {
        guard let projectType = plan.project.projectType else {
            throw PlanError.unknownProjectType(plan.project.type)
        }

        var configuration = self
        configuration.build.projectType = projectType
        configuration.build.testTarget = plan.project.testTarget
        configuration.filter.sourcesPath = PlanMaterializer.absolute(plan.scope.sourcesPath, in: projectPath)
        configuration.filter.excludePatterns = plan.scope.excludePatterns
        configuration.filter.operators = plan.scope.operators
        return configuration
    }
}
