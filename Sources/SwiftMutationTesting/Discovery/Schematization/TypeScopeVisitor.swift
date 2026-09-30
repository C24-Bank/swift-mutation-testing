import SwiftSyntax

final class TypeScopeVisitor: SyntaxVisitor {

    init() {
        super.init(viewMode: .sourceAccurate)
    }

    private(set) var scopes: [FunctionBodyScope] = []

    override func visit(_ node: FunctionDeclSyntax) -> SyntaxVisitorContinueKind {
        record(body: node.body, returnsValue: Self.returnsValue(node.signature.returnClause))
        return .visitChildren
    }

    override func visit(_ node: InitializerDeclSyntax) -> SyntaxVisitorContinueKind {
        record(body: node.body)
        return .visitChildren
    }

    override func visit(_ node: DeinitializerDeclSyntax) -> SyntaxVisitorContinueKind {
        record(body: node.body)
        return .visitChildren
    }

    override func visit(_ node: AccessorDeclSyntax) -> SyntaxVisitorContinueKind {
        record(body: node.body, returnsValue: node.accessorSpecifier.tokenKind == .keyword(.get))
        return .visitChildren
    }

    private func record(body: CodeBlockSyntax?, returnsValue: Bool = false) {
        guard let body else { return }
        scopes.append(
            FunctionBodyScope(
                bodyStartOffset: body.position.utf8Offset,
                bodyEndOffset: body.endPosition.utf8Offset,
                statementsStartOffset: body.statements.position.utf8Offset,
                statementsEndOffset: body.statements.endPosition.utf8Offset,
                shape: Self.shape(of: body.statements, returnsValue: returnsValue)
            )
        )
    }

    private static func shape(of statements: CodeBlockItemListSyntax, returnsValue: Bool) -> FunctionBodyShape {
        guard statements.count == 1, let item = statements.first?.item else { return .statements }

        let expression: ExprSyntax?
        switch item {
        case .expr(let expr): expression = expr
        case .stmt(let stmt): expression = stmt.as(ExpressionStmtSyntax.self)?.expression
        case .decl: expression = nil
        }

        guard let expression else { return .statements }

        return expression.is(IfExprSyntax.self) || expression.is(SwitchExprSyntax.self)
            ? .conditional(returnsValue: returnsValue)
            : .expression
    }

    private static func returnsValue(_ returnClause: ReturnClauseSyntax?) -> Bool {
        guard let type = returnClause?.type.trimmedDescription else { return false }
        return type != "Void" && type != "()"
    }

    func isSchematizable(utf8Offset: Int) -> Bool {
        scopes.contains {
            $0.bodyStartOffset <= utf8Offset && utf8Offset < $0.bodyEndOffset
        }
    }

    func innermostScope(containing utf8Offset: Int) -> FunctionBodyScope? {
        scopes
            .filter { $0.bodyStartOffset <= utf8Offset && utf8Offset < $0.bodyEndOffset }
            .min { ($0.bodyEndOffset - $0.bodyStartOffset) < ($1.bodyEndOffset - $1.bodyStartOffset) }
    }
}
