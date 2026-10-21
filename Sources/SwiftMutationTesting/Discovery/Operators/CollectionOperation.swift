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

        if let swapped = Self.swaps[name.text] {
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
            let firstToken = node.firstToken(viewMode: .sourceAccurate)
        else { return .visitChildren }

        append(
            at: firstToken,
            original: node.trimmedDescription,
            mutated: base.trimmedDescription,
            description: "remove .filter"
        )
        return .visitChildren
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
