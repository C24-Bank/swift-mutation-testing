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

    @Test("Given a filter assigned back to its own base, when visited, then it is not dropped")
    func filterAssignedToItselfIsSkipped() {
        #expect(mutated("func f() { deleted = deleted.filter { $0 != id } }").isEmpty)
    }

    @Test("Given a filter on an optional chain, when visited, then the chain's question mark is dropped too")
    func filterOnOptionalChain() {
        #expect(mutated("func f() { _ = images?.filter { $0.isLarge } }") == ["images?.filter { $0.isLarge } → images"])
    }

    @Test("Given lookups by a single equality, when visited, then first and last are not swapped")
    func keyLookupsAreSkipped() {
        let code = """
            func f() {
                _ = accounts.first { $0.accountNumber == number }
                _ = bookings.first(where: { $0.id == id })
                _ = items.last { item in return item.key === key }
            }
            """
        #expect(mutated(code).isEmpty)
    }

    @Test("Given a compound condition or a fallback chain, when visited, then first and last are still swapped")
    func compoundConditionsAndFallbacksAreKept() {
        let code = """
            func f() {
                _ = items.first { $0.type == .card && $0.status == .pending }
                _ = yearData.last ?? yearData.first
            }
            """
        #expect(mutated(code) == ["first → last", "last → first", "first → last"])
    }

    @Test("Given a variable, an enum case or a static member named first, when visited, then nothing is mutated")
    func namesThatAreNotCollectionsAreSkipped() {
        #expect(mutated("func f() { let first = 1; _ = Order.first == x ? first : 0; g(.first) }").isEmpty)
    }
}
