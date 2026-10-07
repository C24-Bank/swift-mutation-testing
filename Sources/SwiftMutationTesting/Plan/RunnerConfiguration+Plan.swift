extension RunnerConfiguration {
    func applying(_ plan: Plan) throws -> RunnerConfiguration {
        guard let projectType = plan.project.projectType else {
            throw PlanError.unknownProjectType(plan.project.type)
        }

        var configuration = self
        configuration.build.projectType = projectType
        configuration.build.testTarget = plan.project.testTarget
        configuration.build.xcodeContainer = plan.project.xcodeContainer
        configuration.filter.sourcesPath = PlanMaterializer.absolute(plan.scope.sourcesPath, in: projectPath)
        configuration.filter.excludePatterns = plan.scope.excludePatterns
        configuration.filter.operators = plan.scope.operators
        return configuration
    }
}
