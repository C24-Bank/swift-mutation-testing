import SwiftSyntax

final class NegateConditionalVisitor: MutationSyntaxVisitor, OperatorVisitor {
    static let operatorIdentifier = "NegateConditional"
    static let summary = "Negate conditional"
    static let explanation =
        "Wraps a condition in !(...). A survivor usually means only one side of the branch is tested."

    override func visit(_ node: ConditionElementSyntax) -> SyntaxVisitorContinueKind {
        guard case .expression(let expr) = node.condition,
            let firstToken = expr.firstToken(viewMode: .sourceAccurate)
        else {
            return .visitChildren
        }

        let originalText = expr.trimmedDescription
        let location = firstToken.startLocation(converter: locationConverter)

        mutations.append(
            MutationPoint(
                operatorIdentifier: Self.operatorIdentifier,
                filePath: filePath,
                line: location.line,
                column: location.column,
                utf8Offset: firstToken.positionAfterSkippingLeadingTrivia.utf8Offset,
                originalText: originalText,
                mutatedText: "!(\(originalText))",
                replacement: .wrapWithNegation,
                description: "\(originalText) → !(\(originalText))"
            )
        )

        return .visitChildren
    }
}
