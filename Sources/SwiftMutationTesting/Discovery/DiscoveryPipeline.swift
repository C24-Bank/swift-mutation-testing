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
        let sourceFiles = try FileDiscoveryStage().run(input: input)
        let parsedSources = await ParsingStage().run(sourceFiles: sourceFiles)
        let ops = resolvedOperators(from: input.operators)
        let mutationPoints = await MutantDiscoveryStage(operators: ops).run(sources: parsedSources)
        let indexed = MutantIndexingStage().run(
            mutationPoints: mutationPoints, sources: parsedSources, projectPath: input.projectPath
        )
        let (schematizedFiles, schematizableDescriptors) = SchematizationStage()
            .run(indexed: indexed, sources: parsedSources)
        let importStyle = ImportStyle.of(parsedSources)
        let incompatibleDescriptors = IncompatibleRewritingStage().run(indexed: indexed, sources: parsedSources)
        let allDescriptors = (schematizableDescriptors + incompatibleDescriptors)
            .sorted { indexFromID($0.id) < indexFromID($1.id) }

        return RunnerInput(
            projectPath: input.projectPath,
            projectType: input.projectType,
            timeout: input.timeout,
            concurrency: input.concurrency,
            noCache: input.noCache,
            schematizedFiles: schematizedFiles,
            mutants: allDescriptors,
            importStyle: importStyle
        )
    }

    private func indexFromID(_ id: String) -> Int {
        Int(id.replacingOccurrences(of: "swift-mutation-testing_", with: ""))!
    }

    private func resolvedOperators(from identifiers: [String]) -> [any MutationOperator] {
        if identifiers.isEmpty {
            return Self.registry.map(\.operator)
        }

        return Self.registry.compactMap { identifiers.contains($0.name) ? $0.operator : nil }
    }
}
