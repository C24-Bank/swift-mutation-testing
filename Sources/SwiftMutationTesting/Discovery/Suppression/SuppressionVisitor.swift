import SwiftSyntax

/// Finds the code a user asked to leave unmutated.
///
/// Two comment directives, which need nothing declared and so never break the user's build:
///
/// - `// swift-mutation-testing:disable` in the comments right above a declaration — a function, an
///   initializer, a type, an extension, a property — suppresses the whole declaration;
/// - `// swift-mutation-testing:disable-next-line`, anywhere, suppresses the line that follows it.
///
/// The `@SwiftMutationTestingDisabled` attribute is still honoured for projects that declared it themselves.
final class SuppressionVisitor: SyntaxVisitor {
    static let disableDirective = "swift-mutation-testing:disable"
    static let disableNextLineDirective = "swift-mutation-testing:disable-next-line"
    static let attributeName = "SwiftMutationTestingDisabled"

    private let converter: SourceLocationConverter
    private(set) var suppressedRanges: [Range<AbsolutePosition>] = []

    init(converter: SourceLocationConverter) {
        self.converter = converter
        super.init(viewMode: .sourceAccurate)
    }

    override func visit(_ node: FunctionDeclSyntax) -> SyntaxVisitorContinueKind {
        declaration(node, attributes: node.attributes)
    }

    override func visit(_ node: InitializerDeclSyntax) -> SyntaxVisitorContinueKind {
        declaration(node, attributes: node.attributes)
    }

    override func visit(_ node: DeinitializerDeclSyntax) -> SyntaxVisitorContinueKind {
        declaration(node, attributes: node.attributes)
    }

    override func visit(_ node: SubscriptDeclSyntax) -> SyntaxVisitorContinueKind {
        declaration(node, attributes: node.attributes)
    }

    override func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind {
        declaration(node, attributes: node.attributes)
    }

    override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
        declaration(node, attributes: node.attributes)
    }

    override func visit(_ node: EnumDeclSyntax) -> SyntaxVisitorContinueKind {
        declaration(node, attributes: node.attributes)
    }

    override func visit(_ node: ActorDeclSyntax) -> SyntaxVisitorContinueKind {
        declaration(node, attributes: node.attributes)
    }

    override func visit(_ node: ExtensionDeclSyntax) -> SyntaxVisitorContinueKind {
        declaration(node, attributes: node.attributes)
    }

    override func visit(_ node: VariableDeclSyntax) -> SyntaxVisitorContinueKind {
        declaration(node, attributes: node.attributes)
    }

    override func visit(_ token: TokenSyntax) -> SyntaxVisitorContinueKind {
        for (piece, position) in comments(of: token) where Self.directive(in: piece) == Self.disableNextLineDirective {
            suppressLine(after: position)
        }
        return .visitChildren
    }

    // MARK: - Private

    private func declaration(_ node: some SyntaxProtocol, attributes: AttributeListSyntax) -> SyntaxVisitorContinueKind
    {
        let commented = node.leadingTrivia.contains { Self.directive(in: $0) == Self.disableDirective }
        guard commented || hasDisablingAttribute(attributes) else { return .visitChildren }

        suppressedRanges.append(node.positionAfterSkippingLeadingTrivia ..< node.endPositionBeforeTrailingTrivia)
        return .visitChildren
    }

    private func hasDisablingAttribute(_ attributes: AttributeListSyntax) -> Bool {
        attributes.contains { element in
            guard case .attribute(let attribute) = element,
                let name = attribute.attributeName.as(IdentifierTypeSyntax.self)
            else { return false }
            return name.name.text == Self.attributeName
        }
    }

    /// The line comments around a token, each with the position where it starts.
    private func comments(of token: TokenSyntax) -> [(TriviaPiece, AbsolutePosition)] {
        var found: [(TriviaPiece, AbsolutePosition)] = []
        var position = token.position
        for piece in token.leadingTrivia {
            found.append((piece, position))
            position = position.advanced(by: piece.sourceLength.utf8Length)
        }
        position = token.endPositionBeforeTrailingTrivia
        for piece in token.trailingTrivia {
            found.append((piece, position))
            position = position.advanced(by: piece.sourceLength.utf8Length)
        }
        return found
    }

    private func suppressLine(after position: AbsolutePosition) {
        let line = converter.location(for: position).line + 1
        let start = converter.position(ofLine: line, column: 1)
        let end = converter.position(ofLine: line + 1, column: 1)
        if start < end {
            suppressedRanges.append(start ..< end)
        }
    }

    /// The directive a `//` comment carries — its first word — or `nil`; text after it is the reason.
    static func directive(in piece: TriviaPiece) -> String? {
        guard case .lineComment(let text) = piece else { return nil }
        let body = text.dropFirst(2).drop { $0 == " " || $0 == "\t" }
        let word = body.prefix { !$0.isWhitespace }
        return word.hasPrefix("swift-mutation-testing:") ? String(word) : nil
    }
}
