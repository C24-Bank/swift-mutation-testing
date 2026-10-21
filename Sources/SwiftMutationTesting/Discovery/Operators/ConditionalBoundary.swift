import SwiftSyntax

/// Moves a comparison's boundary (`<` ↔ `<=`, `>` ↔ `>=`), so the value at the edge must be tested.
struct ConditionalBoundary: Sendable, MutationOperator {
    func mutations(in source: ParsedSource) -> [MutationPoint] {
        let visitor = ConditionalBoundaryVisitor(source: source)
        visitor.walk(source.syntax)
        return visitor.mutations
    }
}

final class ConditionalBoundaryVisitor: MutationSyntaxVisitor {
    private static let boundaries = ["<": "<=", "<=": "<", ">": ">=", ">=": ">"]

    override func visit(_ token: TokenSyntax) -> SyntaxVisitorContinueKind {
        guard case .binaryOperator(let operatorText) = token.tokenKind,
            let replacement = Self.boundaries[operatorText]
        else { return .visitChildren }

        let location = token.startLocation(converter: locationConverter)
        mutations.append(
            MutationPoint(
                operatorIdentifier: "ConditionalBoundary",
                filePath: filePath,
                line: location.line,
                column: location.column,
                utf8Offset: token.positionAfterSkippingLeadingTrivia.utf8Offset,
                originalText: operatorText,
                mutatedText: replacement,
                replacement: .binaryOperator,
                description: "\(operatorText) → \(replacement)"
            )
        )
        return .visitChildren
    }
}
