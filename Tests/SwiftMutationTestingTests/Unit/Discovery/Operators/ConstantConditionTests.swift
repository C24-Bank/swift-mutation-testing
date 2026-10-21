import Testing

@testable import SwiftMutationTesting

@Suite("ConstantCondition")
struct ConstantConditionTests {
    private let op = ConstantCondition()

    private func mutated(_ code: String) -> [String] {
        op.mutations(in: makeParsedSource(code)).map { "\($0.originalText) → \($0.mutatedText)" }
    }

    @Test("Given a guard condition, when visited, then it is replaced with true and with false")
    func guardConditionBecomesBothConstants() {
        #expect(mutated("func f() { guard isVisible else { return } }") == ["isVisible → true", "isVisible → false"])
    }

    @Test("Given if and while conditions, when visited, then each gets both constants")
    func ifAndWhileConditions() {
        #expect(
            mutated("func f() { if a && b {}; while count > 0 {} }")
                == ["a && b → true", "a && b → false", "count > 0 → true", "count > 0 → false"]
        )
    }

    @Test("Given several conditions in one if, when visited, then each is replaced on its own")
    func conditionListElements() {
        #expect(mutated("func f() { if a, b {} }") == ["a → true", "a → false", "b → true", "b → false"])
    }

    @Test("Given optional binding, case pattern and literal conditions, when visited, then nothing is mutated")
    func bindingsAndLiteralsAreSkipped() {
        #expect(mutated("func f() { if let x = y {}; guard case .a = e else { return }; while true {} }").isEmpty)
    }

    @Test("Given a ternary, when visited, then its condition is replaced with both constants")
    func ternaryCondition() {
        #expect(mutated("func f() { let v = isOn ? 1 : 2 }") == ["isOn → true", "isOn → false"])
    }

    @Test("Given a ternary with a comparison, when visited, then the whole comparison is replaced")
    func ternaryComparisonCondition() {
        #expect(mutated("func f() { let v = a == b ? 1 : 2 }") == ["a == b → true", "a == b → false"])
    }

    @Test("Given a ternary inside an assignment, when visited, then it is skipped")
    func ternaryInAssignmentIsSkipped() {
        #expect(mutated("func f() { v = isOn ? 1 : 2; w += isOn ? 1 : 2 }").isEmpty)
    }

    @Test("Given a mutation, when described, then it names the condition and the constant")
    func mutationMetadata() throws {
        let point = try #require(op.mutations(in: makeParsedSource("func f() { if ok {} }")).first)

        #expect(point.operatorIdentifier == "ConstantCondition")
        #expect(point.replacement == .constantCondition)
        #expect(point.description == "ok → true")
    }
}
