import SwiftSyntax

enum ImportStyle: String, Sendable, Equatable {
    case implicit
    case explicit

    static func of(_ sources: [ParsedSource]) -> ImportStyle {
        sources.contains { of($0.syntax) == .explicit } ? .explicit : .implicit
    }

    static func of(_ syntax: SourceFileSyntax) -> ImportStyle {
        imports(in: syntax).contains { !$0.modifiers.isEmpty } ? .explicit : .implicit
    }

    static func importsFoundation(_ syntax: SourceFileSyntax) -> Bool {
        imports(in: syntax).contains { $0.path.first?.name.text == "Foundation" }
    }

    private static func imports(in syntax: SourceFileSyntax) -> [ImportDeclSyntax] {
        syntax.statements.compactMap { $0.item.as(ImportDeclSyntax.self) }
    }
}
