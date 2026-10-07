import SwiftSyntax

final class BooleanLiteralVisitor: MutationSyntaxVisitor, OperatorVisitor {
    static let operatorIdentifier = "BooleanLiteralReplacement"
    static let summary = "Boolean literal replacement"
    static let explanation =
        "Replaces true with false and false with true. A survivor usually means a flag's effect is not asserted."

    override func visit(_ node: BooleanLiteralExprSyntax) -> SyntaxVisitorContinueKind {
        let token = node.literal
        let isTrue = token.tokenKind == .keyword(.true)
        let originalText = token.trimmedDescription
        let mutatedText = isTrue ? "false" : "true"

        mutations.append(
            MutationPoint(
                operatorIdentifier: Self.operatorIdentifier,
                filePath: filePath,
                line: token.startLocation(converter: locationConverter).line,
                column: token.startLocation(converter: locationConverter).column,
                utf8Offset: token.positionAfterSkippingLeadingTrivia.utf8Offset,
                originalText: originalText,
                mutatedText: mutatedText,
                replacement: .booleanLiteral,
                description: "\(originalText) → \(mutatedText)"
            )
        )

        return .visitChildren
    }
}
