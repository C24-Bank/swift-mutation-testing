import Testing

@testable import SwiftMutationTesting

@Suite("ConditionalBoundary")
struct ConditionalBoundaryTests {
    private let op = ConditionalBoundary()

    private func mutated(_ code: String) -> [String] {
        op.mutations(in: makeParsedSource(code)).map(\.description)
    }

    @Test("Given each comparison, when visited, then only its boundary moves")
    func eachComparisonMovesItsBoundary() {
        #expect(
            mutated("func f() { _ = a < b; _ = a <= b; _ = a > b; _ = a >= b }")
                == ["< → <=", "<= → <", "> → >=", ">= → >"]
        )
    }

    @Test("Given equality, generics and ranges, when visited, then nothing is mutated")
    func equalityGenericsAndRangesAreSkipped() {
        #expect(mutated("func f<T>(x: [T]) { _ = a == b; _ = a != b; _ = 0..<3; let y: Array<Int> = [] }").isEmpty)
    }
}
