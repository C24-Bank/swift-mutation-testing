/// Replaces a branch condition with `true` and with `false`, so each branch must be checked by its own test.
struct ConstantCondition: Sendable, MutationOperator {
    func mutations(in source: ParsedSource) -> [MutationPoint] {
        let visitor = ConstantConditionVisitor(source: source)
        visitor.walk(source.syntax)
        return visitor.mutations
    }
}
