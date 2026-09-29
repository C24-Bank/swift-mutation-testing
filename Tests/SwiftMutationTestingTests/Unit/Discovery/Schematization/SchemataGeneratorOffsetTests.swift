import SwiftParser
import SwiftSyntax
import Testing

@testable import SwiftMutationTesting

@Suite("SchemataGenerator offsets")
struct SchemataGeneratorOffsetTests {

    @Test(
        "Given content shorter than the syntax it was parsed from, when generating, then the content is returned"
    )
    func contentShorterThanTheSyntaxIsLeftAlone() {
        let parsed = "func f() -> Bool {\n    let flag = true\n    return flag\n}\n"
        let source = ParsedSource(
            file: SourceFile(path: "test.swift", content: "func f() {}"),
            syntax: Parser.parse(source: parsed)
        )
        let point = MutationPoint(
            operatorIdentifier: "BooleanLiteralReplacement",
            filePath: "test.swift", line: 2, column: 16, utf8Offset: 34,
            originalText: "true", mutatedText: "false",
            replacement: .booleanLiteral, description: "true → false"
        )

        let result = SchemataGenerator().generate(source: source, mutations: [(index: 0, point: point)])

        #expect(result == "func f() {}")
    }

    @Test("Given a mutation whose text runs past the body it belongs to, when generating, then the body is unchanged")
    func aMutationRunningPastTheBodyLeavesItUnchanged() {
        let code = "func f() -> Bool {\n    let flag = true\n    return flag\n}\n"
        let source = makeParsedSource(code)
        let real = BooleanLiteralReplacement().mutations(in: source)[0]
        let point = MutationPoint(
            operatorIdentifier: real.operatorIdentifier,
            filePath: real.filePath, line: real.line, column: real.column,
            utf8Offset: real.utf8Offset,
            originalText: String(repeating: "x", count: 500), mutatedText: real.mutatedText,
            replacement: real.replacement, description: real.description
        )

        let result = SchemataGenerator().generate(source: source, mutations: [(index: 0, point: point)])

        #expect(result.contains("swift-mutation-testing_0"))
        #expect(!result.contains("false"))
    }
}
