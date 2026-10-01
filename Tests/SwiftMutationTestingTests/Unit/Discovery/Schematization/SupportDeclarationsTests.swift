import SwiftParser
import SwiftSyntax
import Testing

@testable import SwiftMutationTesting

@Suite("SupportDeclarations")
struct SupportDeclarationsTests {
    private let path = "/project/Sources/Foo.swift"

    @Test("Given the per-file declarations, when parsed, then they are valid Swift")
    func perFileDeclarationsParse() {
        let syntax = Parser.parse(source: SupportDeclarations.perFile(for: path))

        #expect(!syntax.hasError)
    }

    @Test("Given the per-file declarations, when read, then each one is internal and usable from inlinable code")
    func everyDeclarationIsUsableFromInline() {
        let declarations = Parser.parse(source: SupportDeclarations.perFile(for: path)).statements.compactMap {
            $0.item.as(DeclSyntax.self)
        }
        let nonImports = declarations.filter { !$0.is(ImportDeclSyntax.self) }

        #expect(nonImports.count == 2)
        #expect(nonImports.allSatisfy { $0.description.contains("@usableFromInline") })
        #expect(nonImports.allSatisfy { $0.description.contains("internal ") })
        #expect(nonImports.allSatisfy { !$0.description.contains("private ") })
    }

    @Test("Given two files, when their declarations are named, then the names differ and are stable")
    func namesFollowTheFile() {
        let other = "/project/Sources/Bar.swift"

        #expect(SupportDeclarations.identifier(for: path) == SupportDeclarations.identifier(for: path))
        #expect(SupportDeclarations.identifier(for: path) != SupportDeclarations.identifier(for: other))
        #expect(SupportDeclarations.identifier(for: path).hasPrefix("__swiftMutationTestingID_"))
        #expect(SupportDeclarations.suffix(for: path).count == 8)
        #expect(SupportDeclarations.suffix(for: path).allSatisfy { $0.isHexDigit })
    }

    @Test("Given the per-file declarations, when read, then activation writes the marker file once, off any actor")
    func activationWritesTheMarkerOnce() {
        let block = SupportDeclarations.perFile(for: path)
        let suffix = SupportDeclarations.suffix(for: path)

        #expect(block.contains("@usableFromInline nonisolated static func activated()"))
        #expect(block.contains("nonisolated(unsafe) static var activationRecorded = false"))
        #expect(block.contains(#"environment["__SWIFT_MUTATION_TESTING_ACTIVATION_FILE"]"#))
        #expect(block.contains("FileManager.default.createFile(atPath: path, contents: nil)"))
        #expect(SupportDeclarations.activationCall(for: path) == "__SwiftMutationTesting_\(suffix).activated()")
    }

    @Test("Given the per-file declarations, when read, then the ID is read once from the environment, off any actor")
    func theIDIsReadLazilyFromTheEnvironment() {
        let block = SupportDeclarations.perFile(for: path)
        let suffix = SupportDeclarations.suffix(for: path)

        #expect(block.contains("@usableFromInline nonisolated static let id: String ="))
        #expect(block.contains(#"environment["__SWIFT_MUTATION_TESTING_ACTIVE"]"#))
        #expect(block.contains("@usableFromInline nonisolated internal var __swiftMutationTestingID_\(suffix): String {"))
        #expect(block.contains("__SwiftMutationTesting_\(suffix).id"))
    }
}
