import SwiftParser
import SwiftSyntax
import Testing

@testable import SwiftMutationTesting

@Suite("SupportDeclarations")
struct SupportDeclarationsTests {

    @Test("Given the per-file declarations, when parsed, then they are valid Swift")
    func perFileDeclarationsParse() {
        let syntax = Parser.parse(source: SupportDeclarations.perFile)

        #expect(!syntax.hasError)
    }

    @Test("Given the per-file declarations, when read, then nothing in them is visible outside the file")
    func everyDeclarationIsPrivate() {
        let declarations = Parser.parse(source: SupportDeclarations.perFile).statements.compactMap {
            $0.item.as(DeclSyntax.self)
        }
        let nonImports = declarations.filter { !$0.is(ImportDeclSyntax.self) }

        #expect(nonImports.count == 2)
        #expect(nonImports.allSatisfy { $0.description.contains("private ") })
    }

    @Test("Given the per-file declarations, when read, then the ID is read once from the environment, off any actor")
    func theIDIsReadLazilyFromTheEnvironment() {
        let block = SupportDeclarations.perFile

        #expect(block.contains("nonisolated static let id: String ="))
        #expect(block.contains(#"environment["__SWIFT_MUTATION_TESTING_ACTIVE"]"#))
        #expect(
            block.contains("nonisolated private var __swiftMutationTestingID: String { __SwiftMutationTesting.id }")
        )
    }
}
