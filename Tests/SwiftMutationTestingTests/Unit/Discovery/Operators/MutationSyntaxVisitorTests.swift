import Testing

@testable import SwiftMutationTesting

@Suite("MutationSyntaxVisitor")
struct MutationSyntaxVisitorTests {
    private let source = makeParsedSource(
        """
        func f(_ a: Bool, _ b: Bool, _ n: Int) -> Bool {
            #if DEBUG && !os(Windows) || compiler(>=6.0)
            let x = a && b
            #elseif swift(<5.9) || os(Linux)
            let x = a || b
            #else
            let x = n * 2 > 1
            #endif
            return x == true
        }
        """
    )

    @Test("Given operators in an #if condition, when visited, then only the code in the branches is mutated")
    func conditionsOfAnIfConfigAreNotMutated() {
        let logical = LogicalOperatorReplacement().mutations(in: source).map(\.line)
        let relational = RelationalOperatorReplacement().mutations(in: source).map(\.line)
        let arithmetic = ArithmeticOperatorReplacement().mutations(in: source).map(\.line)

        #expect(Set(logical) == [3, 5])
        #expect(Set(relational) == [7, 9])
        #expect(Set(arithmetic) == [7])
    }

    @Test("Given a boolean literal inside an #if branch, when visited, then it is still a mutation point")
    func codeInsideAnIfConfigBranchIsStillMutated() {
        let branches = makeParsedSource("func f() -> Bool {\n#if DEBUG\nreturn true\n#else\nreturn false\n#endif\n}")

        #expect(BooleanLiteralReplacement().mutations(in: branches).map(\.line) == [3, 5])
    }
}
