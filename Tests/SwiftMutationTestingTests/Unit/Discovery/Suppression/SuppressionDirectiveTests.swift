import Foundation
import Testing

@testable import SwiftMutationTesting

@Suite("Suppression directives")
struct SuppressionDirectiveTests {
    private let stage = MutantDiscoveryStage(operators: [BooleanLiteralReplacement()])

    private func survivingLines(_ code: String) async -> [Int] {
        await stage.run(sources: [makeParsedSource(code, path: "a.swift")]).map(\.line)
    }

    @Test(
        "Given the disable comment above a declaration, when discovered, then the declaration has no mutant",
        arguments: [
            "func suppressed() -> Bool { true }",
            "init() { let x = true }",
            "deinit { let x = true }",
            "subscript(i: Int) -> Bool { true }",
            "struct S { var x = true }",
            "final class C { var x = true }",
            "enum E { static let x = true }",
            "actor A { var x = true }",
            "extension Int { var flag: Bool { true } }",
            "var flag = true",
        ]
    )
    func theDisableCommentSuppressesTheDeclaration(declaration: String) async {
        let code = """
            struct Host {
                // swift-mutation-testing:disable
                \(declaration)
            }
            func kept() -> Bool { false }
            """

        #expect(await survivingLines(code) == [5])
    }

    @Test(
        "Given the disable comment with a reason after it and other comments around, when discovered, then it still applies"
    )
    func aReasonAfterTheDirectiveIsAllowed() async {
        let code = """
            /// Generated from the schema.
            // swift-mutation-testing:disable — generated code, covered upstream
            @inlinable
            func suppressed() -> Bool { true }
            func kept() -> Bool { false }
            """

        #expect(await survivingLines(code) == [5])
    }

    @Test("Given disable-next-line, when discovered, then only the next line loses its mutants")
    func disableNextLineSuppressesOneLine() async {
        let code = """
            func f() -> [Bool] {
                // swift-mutation-testing:disable-next-line
                let a = true
                let b = false
                return [a, b]
            }
            """

        #expect(await survivingLines(code) == [4])
    }

    @Test("Given disable-next-line as a trailing comment, when discovered, then the line after it is suppressed")
    func disableNextLineAsATrailingComment() async {
        let code = """
            let a = true // swift-mutation-testing:disable-next-line
            let b = false
            let c = true
            """

        #expect(await survivingLines(code) == [1, 3])
    }

    @Test("Given comments that only look like directives, when discovered, then nothing is suppressed")
    func lookalikesAreIgnored() async {
        let code = """
            // swift-mutation-testing:disabled
            func a() -> Bool { true }
            /* swift-mutation-testing:disable */
            func b() -> Bool { true }
            // see swift-mutation-testing:disable in the docs
            func c() -> Bool { true }
            """

        #expect(await survivingLines(code) == [2, 4, 6])
    }

    @Test("Given the attribute a project declared itself, when discovered, then it still suppresses")
    func theAttributeIsStillHonoured() async {
        let code = """
            @SwiftMutationTestingDisabled
            func suppressed() -> Bool { true }
            func kept() -> Bool { false }
            """

        #expect(await survivingLines(code) == [3])
    }

    @Test("Given a declaration suppressed by the comment, when the real compiler typechecks it, then it compiles")
    func theDirectiveCompiles() throws {
        let dir = try FileHelpers.makeTemporaryDirectory()
        defer { FileHelpers.cleanup(dir) }
        let file = dir.appendingPathComponent("Suppressed.swift")
        try """
        // swift-mutation-testing:disable
        func suppressed() -> Bool { 1 < 2 }

        func partly() -> Bool {
            // swift-mutation-testing:disable-next-line
            let a = true
            return a
        }
        """.write(to: file, atomically: true, encoding: .utf8)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
        process.arguments = ["swiftc", "-typecheck", file.path]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()

        #expect(process.terminationStatus == 0)
    }
}
