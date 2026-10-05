struct DiscoveryPipeline: Sendable {
    private static let registry: [(name: String, tier: OperatorTier, operator: any MutationOperator)] = [
        (name: "RelationalOperatorReplacement", tier: .experimental, operator: RelationalOperatorReplacement()),
        (name: "BooleanLiteralReplacement", tier: .experimental, operator: BooleanLiteralReplacement()),
        (name: "LogicalOperatorReplacement", tier: .conservative, operator: LogicalOperatorReplacement()),
        (name: "ArithmeticOperatorReplacement", tier: .experimental, operator: ArithmeticOperatorReplacement()),
        (name: "NegateConditional", tier: .conservative, operator: NegateConditional()),
        (name: "SwapTernary", tier: .conservative, operator: SwapTernary()),
        (name: "RemoveSideEffects", tier: .experimental, operator: RemoveSideEffects()),
    ]

    static let allOperatorNames: [String] = registry.map(\.name)

    static func operatorNames(upTo tier: OperatorTier) -> [String] {
        registry.filter { $0.tier <= tier }.map(\.name)
    }

    func run(input: DiscoveryInput) async throws -> RunnerInput {
        let planned = try await Planner().plan(input: input)
        return try PlanMaterializer().materialize(
            plan: planned.plan,
            projectPath: input.projectPath,
            sources: planned.sources,
            execution: .init(timeout: input.timeout, concurrency: input.concurrency, noCache: input.noCache)
        )
    }

    static func operators(named identifiers: [String]) -> [any MutationOperator] {
        if identifiers.isEmpty {
            return registry.map(\.operator)
        }

        return registry.compactMap { identifiers.contains($0.name) ? $0.operator : nil }
    }
}
