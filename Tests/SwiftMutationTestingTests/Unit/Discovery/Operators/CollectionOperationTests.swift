import Testing

@testable import SwiftMutationTesting

@Suite("CollectionOperation")
struct CollectionOperationTests {
    private let op = CollectionOperation()

    private func mutated(_ code: String) -> [String] {
        op.mutations(in: makeParsedSource(code)).map { "\($0.originalText) → \($0.mutatedText)" }
    }

    @Test("Given first, last, min and max, when visited, then each is swapped with its counterpart")
    func swapsFirstLastMinMax() {
        #expect(
            mutated("func f() { _ = xs.first; _ = xs.last(where: { $0 }); _ = xs.min(); _ = xs.max(by: <) }")
                == ["first → last", "last → first", "min → max", "max → min"]
        )
    }

    @Test("Given a filter call, when visited, then it is replaced by its base")
    func dropsFilter() {
        #expect(mutated("func f() { _ = items.filter { $0.isActive } }") == ["items.filter { $0.isActive } → items"])
    }

    @Test("Given a variable, an enum case or a static member named first, when visited, then nothing is mutated")
    func namesThatAreNotCollectionsAreSkipped() {
        #expect(mutated("func f() { let first = 1; _ = Order.first == x ? first : 0; g(.first) }").isEmpty)
    }
}
