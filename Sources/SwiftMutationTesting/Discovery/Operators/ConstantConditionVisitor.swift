import SwiftSyntax

final class ConstantConditionVisitor: MutationSyntaxVisitor {
    private static let constants = ["true", "false"]
    private static let comparisons: Set<String> = ["==", "!=", "<=", ">=", "===", "!=="]

    override func visit(_ node: ConditionElementSyntax) -> SyntaxVisitorContinueKind {
        guard case .expression(let expr) = node.condition,
            let firstToken = expr.firstToken(viewMode: .sourceAccurate)
        else { return .visitChildren }

        appendConstants(replacing: expr.trimmedDescription, at: firstToken)
        return .visitChildren
    }

    override func visit(_ node: UnresolvedTernaryExprSyntax) -> SyntaxVisitorContinueKind {
        guard let elements = node.parent?.as(ExprListSyntax.self).map(Array.init),
            let ternaryIndex = elements.firstIndex(where: { $0.position == node.position }),
            ternaryIndex > 0
        else { return .visitChildren }

        let conditionStart = conditionStartIndex(in: elements, before: ternaryIndex)
        let conditionElements = elements[conditionStart ..< ternaryIndex]

        guard !conditionElements.contains(where: isAssignment),
            let firstToken = conditionElements.first?.firstToken(viewMode: .sourceAccurate)
        else { return .visitChildren }

        let condition = conditionElements.map(\.description).joined()
            .trimmingCharacters(in: .whitespacesAndNewlines)
        appendConstants(replacing: condition, at: firstToken)
        return .visitChildren
    }

    private func appendConstants(replacing condition: String, at firstToken: TokenSyntax) {
        guard !Self.constants.contains(condition) else { return }

        let location = firstToken.startLocation(converter: locationConverter)
        for constant in Self.constants {
            mutations.append(
                MutationPoint(
                    operatorIdentifier: "ConstantCondition",
                    filePath: filePath,
                    line: location.line,
                    column: location.column,
                    utf8Offset: firstToken.positionAfterSkippingLeadingTrivia.utf8Offset,
                    originalText: condition,
                    mutatedText: constant,
                    replacement: .constantCondition,
                    description: "\(condition) → \(constant)"
                )
            )
        }
    }

    private func conditionStartIndex(in elements: [ExprSyntax], before ternaryIndex: Int) -> Int {
        for index in stride(from: ternaryIndex - 1, through: 0, by: -1)
        where elements[index].is(UnresolvedTernaryExprSyntax.self) {
            return index + 1
        }
        return 0
    }

    private func isAssignment(_ element: ExprSyntax) -> Bool {
        if element.is(AssignmentExprSyntax.self) { return true }
        guard let binary = element.as(BinaryOperatorExprSyntax.self) else { return false }
        let text = binary.operator.text
        return text.hasSuffix("=") && !Self.comparisons.contains(text)
    }
}
