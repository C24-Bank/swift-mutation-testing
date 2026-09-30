import SwiftParser
import Testing

@testable import SwiftMutationTesting

@Suite("DeclarationPath")
struct DeclarationPathTests {
    @Test(
        "Given a mutated token, when its declaration path is read, then it names every enclosing declaration",
        arguments: [
            ("struct Parser { func parse(_ text: String, strict: Bool) -> Bool { 1 < 2 } }", "Parser.parse(_:strict:)"),
            ("final class Foo { init(bar: Int) { _ = 1 < 2 } }", "Foo.init(bar:)"),
            ("enum E { case a; subscript(i: Int) -> Bool { 1 < 2 } }", "E.subscript(i:)"),
            ("class C { deinit { _ = 1 < 2 } }", "C.deinit"),
            ("struct S { var flag: Bool { 1 < 2 } }", "S.flag"),
            ("struct S { var flag: Bool { get { 1 < 2 } } }", "S.flag.get"),
            ("extension Array where Element == Int { func f() -> Bool { 1 < 2 } }", "Array.f()"),
            ("struct Outer { struct Inner { func f() -> Bool { 1 < 2 } } }", "Outer.Inner.f()"),
            ("func outer() { func inner() -> Bool { 1 < 2 } }", "outer().inner()"),
            ("actor A { func f() -> Bool { [1].contains { $0 < 2 } } }", "A.f()"),
            ("let threshold = 1 < 2", "threshold"),
            ("_ = 1 < 2", "<top-level>"),
        ]
    )
    func namesEnclosingDeclarations(code: String, expected: String) throws {
        let offset = try #require(code.utf8.firstIndex(of: UInt8(ascii: "<"))).utf16Offset(in: code)

        #expect(DeclarationPath.of(utf8Offset: offset, in: Parser.parse(source: code)) == expected)
    }

    @Test("Given an offset past the end of the file, when its declaration path is read, then it is top-level")
    func offsetOutsideTheFileIsTopLevel() {
        #expect(DeclarationPath.of(utf8Offset: 10_000, in: Parser.parse(source: "func f() {}")) == "<top-level>")
    }
}
