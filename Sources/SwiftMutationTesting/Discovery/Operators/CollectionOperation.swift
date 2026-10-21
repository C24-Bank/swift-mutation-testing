import SwiftSyntax

/// Swaps `first`/`last` and `min`/`max`, and drops a `.filter { … }`, so which elements are picked must be tested.
struct CollectionOperation: Sendable, MutationOperator {
    func mutations(in source: ParsedSource) -> [MutationPoint] {
        let visitor = CollectionOperationVisitor(source: source)
        visitor.walk(source.syntax)
        return visitor.mutations
    }
}

final class CollectionOperationVisitor: MutationSyntaxVisitor {
    private static let swaps = ["first": "last", "last": "first", "min": "max", "max": "min"]

    override func visit(_ node: MemberAccessExprSyntax) -> SyntaxVisitorContinueKind {
        guard let base = node.base, !Self.isTypeName(base) else { return .visitChildren }
        let name = node.declName.baseName

        if let swapped = Self.swaps[name.text], !Self.isKeyLookup(node) {
            append(
                at: name,
                original: name.text,
                mutated: swapped,
                description: ".\(name.text) → .\(swapped)"
            )
        }
        return .visitChildren
    }

    override func visit(_ node: FunctionCallExprSyntax) -> SyntaxVisitorContinueKind {
        guard let member = node.calledExpression.as(MemberAccessExprSyntax.self),
            member.declName.baseName.text == "filter",
            let base = member.base,
            let firstToken = node.firstToken(viewMode: .sourceAccurate),
            !Self.isSelfAssignment(of: base, from: node)
        else { return .visitChildren }

        let unfiltered = base.as(OptionalChainingExprSyntax.self)?.expression ?? base
        append(
            at: firstToken,
            original: node.trimmedDescription,
            mutated: unfiltered.trimmedDescription,
            description: "remove .filter"
        )
        return .visitChildren
    }

    /// `items = items.filter { … }` without the filter is `items = items`, which Swift rejects.
    private static func isSelfAssignment(of base: ExprSyntax, from call: FunctionCallExprSyntax) -> Bool {
        guard let elements = call.parent?.as(ExprListSyntax.self).map(Array.init),
            let index = elements.firstIndex(where: { $0.id == ExprSyntax(call).id }),
            index >= 2,
            elements[index - 1].is(AssignmentExprSyntax.self)
        else { return false }
        return elements[index - 2].trimmedDescription == base.trimmedDescription
    }

    /// `first { $0.id == id }`: with a unique key, first and last find the same element.
    private static func isKeyLookup(_ member: MemberAccessExprSyntax) -> Bool {
        guard ["first", "last"].contains(member.declName.baseName.text),
            let call = member.parent?.as(FunctionCallExprSyntax.self),
            call.calledExpression.id == member.id,
            let closure = call.trailingClosure ?? call.arguments.first?.expression.as(ClosureExprSyntax.self),
            closure.statements.count == 1,
            let statement = closure.statements.first?.item
        else { return false }

        let expression: ExprSyntax?
        switch statement {
        case .expr(let expr): expression = expr
        case .stmt(let stmt): expression = stmt.as(ReturnStmtSyntax.self)?.expression
        default: expression = nil
        }

        guard let sequence = expression?.as(SequenceExprSyntax.self) else { return false }
        let operators = sequence.elements.compactMap { $0.as(BinaryOperatorExprSyntax.self)?.operator.text }
        return operators == ["=="] || operators == ["==="]
    }

    /// `Order.first` names an enum case or static member, not a collection element.
    private static func isTypeName(_ base: ExprSyntax) -> Bool {
        guard let reference = base.as(DeclReferenceExprSyntax.self) else { return false }
        return reference.baseName.text.first?.isUppercase == true
    }

    private func append(at token: TokenSyntax, original: String, mutated: String, description: String) {
        let location = token.startLocation(converter: locationConverter)
        mutations.append(
            MutationPoint(
                operatorIdentifier: "CollectionOperation",
                filePath: filePath,
                line: location.line,
                column: location.column,
                utf8Offset: token.positionAfterSkippingLeadingTrivia.utf8Offset,
                originalText: original,
                mutatedText: mutated,
                replacement: .collectionOperation,
                description: description
            )
        )
    }
}
