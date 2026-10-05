import Testing

@testable import SwiftMutationTesting

@Suite("OperatorTier")
struct OperatorTierTests {

    @Test("Given the three tiers, when compared, then conservative comes before default and default before experimental")
    func tiersAreOrderedFromConservativeToExperimental() {
        #expect(OperatorTier.conservative < .default)
        #expect(OperatorTier.default < .experimental)
        #expect(OperatorTier.allCases == [.conservative, .default, .experimental])
    }

    @Test("Given a tier's name, when read, then it is the tier", arguments: OperatorTier.allCases)
    func aTierIsReadFromItsName(tier: OperatorTier) {
        #expect(OperatorTier(rawValue: tier.rawValue) == tier)
    }

    @Test("Given a name that is no tier, when read, then there is none")
    func anUnknownNameIsNoTier() {
        #expect(OperatorTier(rawValue: "stable") == nil)
    }
}
