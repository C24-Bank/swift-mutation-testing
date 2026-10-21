import SwiftSyntax

/// Replaces a returned value with a trivial one (`true`/`false`, `nil`, `[]`, `[:]`), so the result must be asserted.
struct ReturnValue: Sendable, MutationOperator {
    func mutations(in source: ParsedSource) -> [MutationPoint] {
        let visitor = ReturnValueVisitor(source: source)
        visitor.walk(source.syntax)
        return visitor.mutations
    }
}

final class ReturnValueVisitor: MutationSyntaxVisitor {
    override func visit(_ node: ReturnStmtSyntax) -> SyntaxVisitorContinueKind {
        if let expression = node.expression, let type = returnType(enclosing: Syntax(node)) {
            appendMutations(for: expression, returning: type)
        }
        return .visitChildren
    }

    override func visit(_ node: FunctionDeclSyntax) -> SyntaxVisitorContinueKind {
        if let body = node.body, let type = node.signature.returnClause?.type {
            appendImplicitReturn(in: body.statements, returning: type)
        }
        return .visitChildren
    }

    override func visit(_ node: PatternBindingSyntax) -> SyntaxVisitorContinueKind {
        if let type = node.typeAnnotation?.type, case .getter(let statements) = node.accessorBlock?.accessors {
            appendImplicitReturn(in: statements, returning: type)
        }
        return .visitChildren
    }

    override func visit(_ node: AccessorDeclSyntax) -> SyntaxVisitorContinueKind {
        if node.accessorSpecifier.tokenKind == .keyword(.get), let body = node.body,
            let type = returnType(enclosing: Syntax(node))
        {
            appendImplicitReturn(in: body.statements, returning: type)
        }
        return .visitChildren
    }

    private func appendImplicitReturn(in statements: CodeBlockItemListSyntax, returning type: TypeSyntax) {
        guard statements.count == 1, case .expr(let expression) = statements.first?.item else { return }
        appendMutations(for: expression, returning: type)
    }

    private func appendMutations(for expression: ExprSyntax, returning type: TypeSyntax) {
        let original = expression.trimmedDescription
        guard let firstToken = expression.firstToken(viewMode: .sourceAccurate) else { return }

        let location = firstToken.startLocation(converter: locationConverter)
        for constant in Self.trivialValues(for: type) where constant != original {
            mutations.append(
                MutationPoint(
                    operatorIdentifier: "ReturnValue",
                    filePath: filePath,
                    line: location.line,
                    column: location.column,
                    utf8Offset: firstToken.positionAfterSkippingLeadingTrivia.utf8Offset,
                    originalText: original,
                    mutatedText: constant,
                    replacement: .returnValue,
                    description: "return \(original) → return \(constant)"
                )
            )
        }
    }

    /// The return type of the nearest function, getter or subscript; nil inside a closure.
    private func returnType(enclosing node: Syntax) -> TypeSyntax? {
        var current = node.parent
        while let candidate = current {
            if candidate.is(ClosureExprSyntax.self) { return nil }
            if let function = candidate.as(FunctionDeclSyntax.self) { return function.signature.returnClause?.type }
            if let subscriptDecl = candidate.as(SubscriptDeclSyntax.self) { return subscriptDecl.returnClause.type }
            if let binding = candidate.as(PatternBindingSyntax.self) { return binding.typeAnnotation?.type }
            if candidate.is(InitializerDeclSyntax.self) || candidate.is(DeinitializerDeclSyntax.self) { return nil }
            current = candidate.parent
        }
        return nil
    }

    static func trivialValues(for type: TypeSyntax) -> [String] {
        if type.is(OptionalTypeSyntax.self) || type.is(ImplicitlyUnwrappedOptionalTypeSyntax.self) { return ["nil"] }
        if type.is(ArrayTypeSyntax.self) { return ["[]"] }
        if type.is(DictionaryTypeSyntax.self) { return ["[:]"] }
        guard let identifier = type.as(IdentifierTypeSyntax.self) else { return [] }
        switch identifier.name.text {
        case "Bool": return ["true", "false"]
        case "Array", "Set": return identifier.genericArgumentClause == nil ? [] : ["[]"]
        case "Optional": return ["nil"]
        default: return []
        }
    }
}
