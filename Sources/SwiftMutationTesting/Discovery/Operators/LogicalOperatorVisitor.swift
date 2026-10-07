import SwiftSyntax

final class LogicalOperatorVisitor: MutationSyntaxVisitor, OperatorVisitor {
    static let operatorIdentifier = "LogicalOperatorReplacement"
    static let summary = "Logical operator replacement"
    static let explanation =
        "Replaces && with || and || with &&. A survivor usually means only cases where both sides agree are tested."

    private static let replacementTable: [String: String] = [
        "&&": "||",
        "||": "&&",
    ]

    override func visit(_ token: TokenSyntax) -> SyntaxVisitorContinueKind {
        guard case .binaryOperator(let operatorText) = token.tokenKind,
            let replacement = Self.replacementTable[operatorText]
        else {
            return .visitChildren
        }

        let location = token.startLocation(converter: locationConverter)

        mutations.append(
            MutationPoint(
                operatorIdentifier: Self.operatorIdentifier,
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
