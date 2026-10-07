protocol MutationOperator: Sendable {
    /// The name reports, configuration files and `--operator` use.
    var identifier: String { get }

    /// A short title, and what the operator changes and what a survivor usually means.
    var summary: String { get }
    var explanation: String { get }

    /// Whether a mutation of this operator inside a loop body could keep the loop from ending.
    var isLoopRisky: Bool { get }

    func mutations(in source: ParsedSource) -> [MutationPoint]
}

/// What an operator's visitor declares about it, read through the operator that runs it.
protocol OperatorVisitor: MutationSyntaxVisitor {
    static var operatorIdentifier: String { get }
    static var summary: String { get }
    static var explanation: String { get }
    static var isLoopRisky: Bool { get }
}

extension OperatorVisitor {
    static var isLoopRisky: Bool {
        false
    }
}

/// An operator whose mutations are the points its visitor records in one walk of the file.
struct VisitorOperator<Visitor: OperatorVisitor>: MutationOperator {
    var identifier: String { Visitor.operatorIdentifier }
    var summary: String { Visitor.summary }
    var explanation: String { Visitor.explanation }
    var isLoopRisky: Bool { Visitor.isLoopRisky }

    func mutations(in source: ParsedSource) -> [MutationPoint] {
        let visitor = Visitor(source: source)
        visitor.walk(source.syntax)
        return visitor.mutations
    }
}

typealias RelationalOperatorReplacement = VisitorOperator<RelationalOperatorVisitor>
typealias BooleanLiteralReplacement = VisitorOperator<BooleanLiteralVisitor>
typealias LogicalOperatorReplacement = VisitorOperator<LogicalOperatorVisitor>
typealias ArithmeticOperatorReplacement = VisitorOperator<ArithmeticOperatorVisitor>
typealias NegateConditional = VisitorOperator<NegateConditionalVisitor>
typealias SwapTernary = VisitorOperator<SwapTernaryVisitor>
typealias RemoveSideEffects = VisitorOperator<RemoveSideEffectsVisitor>
