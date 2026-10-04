import Testing

@testable import SwiftMutationTesting

@Suite("InactiveRegionFilter")
struct InactiveRegionFilterTests {
    private let filter = InactiveRegionFilter()
    private let extractor = InactiveRegionExtractor()

    @Test("Given a mutant inside an inactive clause, when filtered, then it is removed")
    func mutantInsideInactiveClauseIsFiltered() {
        let code = """
            func f() -> Int {
                #if os(Windows)
                return 1 + 2
                #else
                return 3 * 4
                #endif
            }
            """
        let source = makeParsedSource(code)
        let mutations = ArithmeticOperatorReplacement().mutations(in: source)
        let ranges = extractor.extractInactiveRanges(from: source.syntax)

        #expect(mutations.count == 2)

        let result = filter.filter(mutations, inactiveRanges: ranges)

        #expect(result.map(\.operatorIdentifier) == ["ArithmeticOperatorReplacement"])
        #expect(result.map(\.line) == [5])
    }

    @Test("Given no inactive ranges, when filtered, then every mutant is kept")
    func noInactiveRangesKeepsEverything() {
        let source = makeParsedSource("func f() { let x = 1 + 2 }")
        let mutations = ArithmeticOperatorReplacement().mutations(in: source)

        let result = filter.filter(mutations, inactiveRanges: [])

        #expect(result.count == mutations.count)
    }

    @Test("Given a mutant in the active clause of a nested #if, when filtered, then it is kept")
    func nestedActiveClauseIsKept() {
        let code = """
            func f() -> Bool {
                #if os(macOS)
                #if arch(wasm32)
                return true
                #else
                return false
                #endif
                #else
                return true
                #endif
            }
            """
        let source = makeParsedSource(code)
        let mutations = BooleanLiteralReplacement().mutations(in: source)
        let ranges = extractor.extractInactiveRanges(from: source.syntax)

        #expect(mutations.count == 3)

        let result = filter.filter(mutations, inactiveRanges: ranges)

        #expect(result.map(\.line) == [6])
    }
}
