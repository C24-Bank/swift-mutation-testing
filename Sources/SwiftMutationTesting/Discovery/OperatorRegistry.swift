/// Every mutation operator, in the order discovery runs them, with the tier it belongs to.
enum OperatorRegistry {
    private static let entries: [(tier: OperatorTier, operator: any MutationOperator)] = [
        (tier: .experimental, operator: RelationalOperatorReplacement()),
        (tier: .experimental, operator: BooleanLiteralReplacement()),
        (tier: .conservative, operator: LogicalOperatorReplacement()),
        (tier: .experimental, operator: ArithmeticOperatorReplacement()),
        (tier: .conservative, operator: NegateConditional()),
        (tier: .conservative, operator: SwapTernary()),
        (tier: .experimental, operator: RemoveSideEffects()),
    ]

    static let allOperatorNames: [String] = entries.map(\.operator.identifier)

    /// The operators whose mutations are left out of loop bodies.
    static let loopRiskyNames: Set<String> = Set(entries.filter(\.operator.isLoopRisky).map(\.operator.identifier))

    static func operatorNames(upTo tier: OperatorTier) -> [String] {
        entries.filter { $0.tier <= tier }.map(\.operator.identifier)
    }

    static func operators(named identifiers: [String]) -> [any MutationOperator] {
        if identifiers.isEmpty {
            return entries.map(\.operator)
        }

        return entries.map(\.operator).filter { identifiers.contains($0.identifier) }
    }

    static func `operator`(named identifier: String) -> (any MutationOperator)? {
        entries.first { $0.operator.identifier == identifier }?.operator
    }
}
