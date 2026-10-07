protocol MutationOperator: Sendable {
    var identifier: String { get }

    var summary: String { get }
    var explanation: String { get }

    var isLoopRisky: Bool { get }

    func mutations(in source: ParsedSource) -> [MutationPoint]
}

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
