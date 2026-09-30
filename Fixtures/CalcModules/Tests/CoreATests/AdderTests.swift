import Testing
@testable import CoreA

@Suite struct AdderTests {
    @Test func adds() { #expect(Adder().add(2, 3) == 5) }
    @Test func positive() { #expect(Adder().isPositive(1)); #expect(!Adder().isPositive(0)) }
}
