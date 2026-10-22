import Foundation
import SwiftSyntax

final class RemoveSideEffectsVisitor: MutationSyntaxVisitor {
    private static let deniedCallee: Set<String> = [
        "print", "debugPrint", "assert", "assertionFailure",
        "precondition", "preconditionFailure", "fatalError",
        "super.init", "self.init",
    ]

    override func visit(_ node: CodeBlockItemSyntax) -> SyntaxVisitorContinueKind {
        guard case .expr(let expr) = node.item,
            let callExpr = expr.as(FunctionCallExprSyntax.self)
        else {
            return .visitChildren
        }

        let callee = callExpr.calledExpression.trimmedDescription

        guard !Self.deniedCallee.contains(callee), !Self.isLoggingOrFramework(callee) else {
            return .visitChildren
        }

        guard !isSoleStatementOfBody(node), !isValueOfIfExpressionBranch(node) else {
            return .visitChildren
        }

        let location = locationConverter.location(for: node.positionAfterSkippingLeadingTrivia)

        mutations.append(
            MutationPoint(
                operatorIdentifier: "RemoveSideEffects",
                filePath: filePath,
                line: location.line,
                column: location.column,
                utf8Offset: node.positionAfterSkippingLeadingTrivia.utf8Offset,
                originalText: expr.trimmedDescription,
                mutatedText: "",
                replacement: .removeStatement,
                description: "remove \(callee)()"
            )
        )

        return .visitChildren
    }

    /// Logging, tracking and `super` calls: removing them changes nothing a unit test should check.
    static func isLoggingOrFramework(_ callee: String) -> Bool {
        if callee.hasPrefix("super.") { return true }
        let words = ["logger", "track", "matomo", "sentry", "analytics", "breadcrumb"]
        return callee.split(separator: ".").contains { component in
            let original = component.trimmingCharacters(in: CharacterSet(charactersIn: "?!"))
            let name = original.lowercased()
            let afterLog = original.dropFirst(3).first
            let isLogCall = name.hasPrefix("log") && (afterLog == nil || afterLog?.isUppercase == true)
            return isLogCall || words.contains { name.contains($0) }
        }
    }

    /// `let x = if c { make() } else { … }`: the branch's only statement is its value, so it cannot be removed.
    private func isValueOfIfExpressionBranch(_ node: CodeBlockItemSyntax) -> Bool {
        guard let list = node.parent?.as(CodeBlockItemListSyntax.self), list.count == 1,
            let block = list.parent?.as(CodeBlockSyntax.self),
            var ifExpr = block.parent?.as(IfExprSyntax.self)
        else { return false }

        while let outer = ifExpr.parent?.as(IfExprSyntax.self) {
            ifExpr = outer
        }
        return !(ifExpr.parent?.is(ExpressionStmtSyntax.self) ?? false)
    }

    private func isSoleStatementOfBody(_ node: CodeBlockItemSyntax) -> Bool {
        guard let list = node.parent?.as(CodeBlockItemListSyntax.self), list.count == 1,
            let owner = list.parent
        else { return false }

        if owner.is(ClosureExprSyntax.self) || owner.is(AccessorBlockSyntax.self)
            || owner.is(SwitchCaseSyntax.self)
        {
            return true
        }

        guard let block = owner.as(CodeBlockSyntax.self), let holder = block.parent
        else { return false }

        return holder.is(FunctionDeclSyntax.self)
            || holder.is(InitializerDeclSyntax.self)
            || holder.is(DeinitializerDeclSyntax.self)
            || holder.is(AccessorDeclSyntax.self)
    }
}
