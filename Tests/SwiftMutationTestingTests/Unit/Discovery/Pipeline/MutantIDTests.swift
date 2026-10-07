import Testing

@testable import SwiftMutationTesting

@Suite("MutantID")
struct MutantIDTests {

    @Test("Given a position, when its id is made and read back, then the same position comes out")
    func anIdRoundTrips() {
        #expect(MutantID.make(index: 12) == "swift-mutation-testing_12")
        #expect(MutantID.index(of: MutantID.make(index: 12)) == 12)
    }

    @Test(
        "Given a string that is not a mutant id, when it is read, then it names no position",
        arguments: ["m0", "swift-mutation-testing_", "swift-mutation-testing_x", "12"]
    )
    func aStringThatIsNotAnIdNamesNoPosition(id: String) {
        #expect(MutantID.index(of: id) == nil)
    }

    @Test("Given ids out of order, when ordered, then they follow their positions, numerically")
    func orderingFollowsPositions() {
        let ids = [10, 2, 1].map(MutantID.make(index:)) + ["m0"]

        #expect(MutantID.ordered(ids, by: { $0 }) == ["m0"] + [1, 2, 10].map(MutantID.make(index:)))
    }
}
