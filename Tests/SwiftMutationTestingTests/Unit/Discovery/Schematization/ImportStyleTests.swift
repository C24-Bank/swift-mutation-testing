import SwiftParser
import Testing

@testable import SwiftMutationTesting

@Suite("ImportStyle")
struct ImportStyleTests {

    @Test("Given imports without access levels, when read, then the style is implicit")
    func bareImportsAreImplicit() {
        #expect(ImportStyle.of(Parser.parse(source: "import Foundation\nimport SwiftSyntax\nfunc f() {}")) == .implicit)
    }

    @Test(
        "Given an import with an access level, when read, then the style is explicit",
        arguments: ["internal import Foundation", "public import Foundation", "private import Darwin"]
    )
    func anImportWithALevelIsExplicit(line: String) {
        #expect(ImportStyle.of(Parser.parse(source: line + "\nfunc f() {}")) == .explicit)
    }

    @Test("Given a file with no import at all, when read, then the style is implicit")
    func noImportIsImplicit() {
        #expect(ImportStyle.of(Parser.parse(source: "func f() {}")) == .implicit)
    }

    @Test("Given several sources, when read together, then one explicit import makes the project explicit")
    func oneExplicitSourceDecidesForAll() {
        let bare = makeParsedSource("import Foundation\nfunc f() {}")
        let explicit = makeParsedSource("internal import Foundation\nfunc g() {}")

        #expect(ImportStyle.of([bare, bare]) == .implicit)
        #expect(ImportStyle.of([bare, explicit]) == .explicit)
    }

    @Test("Given a file, when asked, then it imports Foundation only if an import names it")
    func importingFoundationIsRead() {
        #expect(ImportStyle.importsFoundation(Parser.parse(source: "import Foundation\nfunc f() {}")))
        #expect(ImportStyle.importsFoundation(Parser.parse(source: "public import Foundation\nfunc f() {}")))
        #expect(ImportStyle.importsFoundation(Parser.parse(source: "import Foundation.NSDate\nfunc f() {}")))
        #expect(!ImportStyle.importsFoundation(Parser.parse(source: "import SwiftSyntax\nfunc f() {}")))
    }
}
