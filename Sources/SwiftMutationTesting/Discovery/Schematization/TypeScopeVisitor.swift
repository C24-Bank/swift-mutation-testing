import SwiftSyntax

final class TypeScopeVisitor: SyntaxVisitor {

    init() {
        super.init(viewMode: .sourceAccurate)
    }

    private(set) var scopes: [FunctionBodyScope] = []
    private var bodyDepth = 0
    private var closureScopeStack: [Bool] = []

    override func visit(_ node: FunctionDeclSyntax) -> SyntaxVisitorContinueKind {
        bodyDepth += 1
        record(body: node.body)
        return .visitChildren
    }

    override func visitPost(_ node: FunctionDeclSyntax) {
        bodyDepth -= 1
    }

    override func visit(_ node: InitializerDeclSyntax) -> SyntaxVisitorContinueKind {
        bodyDepth += 1
        record(body: node.body)
        return .visitChildren
    }

    override func visitPost(_ node: InitializerDeclSyntax) {
        bodyDepth -= 1
    }

    override func visit(_ node: DeinitializerDeclSyntax) -> SyntaxVisitorContinueKind {
        bodyDepth += 1
        record(body: node.body)
        return .visitChildren
    }

    override func visitPost(_ node: DeinitializerDeclSyntax) {
        bodyDepth -= 1
    }

    override func visit(_ node: AccessorDeclSyntax) -> SyntaxVisitorContinueKind {
        bodyDepth += 1
        record(body: node.body)
        return .visitChildren
    }

    override func visitPost(_ node: AccessorDeclSyntax) {
        bodyDepth -= 1
    }

    /// A closure outside any body, e.g. in a `lazy var` or stored property initializer, is its own scope.
    override func visit(_ node: ClosureExprSyntax) -> SyntaxVisitorContinueKind {
        let isScope = bodyDepth == 0 && !node.statements.isEmpty
        closureScopeStack.append(isScope)
        guard isScope else { return .visitChildren }
        bodyDepth += 1
        scopes.append(
            FunctionBodyScope(
                bodyStartOffset: node.statements.position.utf8Offset,
                bodyEndOffset: node.statements.endPosition.utf8Offset,
                statementsStartOffset: node.statements.position.utf8Offset,
                statementsEndOffset: node.statements.endPosition.utf8Offset,
                replacesBraces: false
            )
        )
        return .visitChildren
    }

    override func visitPost(_ node: ClosureExprSyntax) {
        if closureScopeStack.removeLast() {
            bodyDepth -= 1
        }
    }

    override func visitPost(_ node: AccessorBlockSyntax) {
        if case .getter = node.accessors {
            bodyDepth -= 1
        }
    }

    override func visit(_ node: AccessorBlockSyntax) -> SyntaxVisitorContinueKind {
        guard case .getter(let statements) = node.accessors else { return .visitChildren }
        bodyDepth += 1
        scopes.append(
            FunctionBodyScope(
                bodyStartOffset: node.leftBrace.position.utf8Offset,
                bodyEndOffset: node.rightBrace.endPosition.utf8Offset,
                statementsStartOffset: statements.position.utf8Offset,
                statementsEndOffset: statements.endPosition.utf8Offset
            )
        )
        return .visitChildren
    }

    private func record(body: CodeBlockSyntax?) {
        guard let body else { return }
        scopes.append(
            FunctionBodyScope(
                bodyStartOffset: body.position.utf8Offset,
                bodyEndOffset: body.endPosition.utf8Offset,
                statementsStartOffset: body.statements.position.utf8Offset,
                statementsEndOffset: body.statements.endPosition.utf8Offset
            )
        )
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
