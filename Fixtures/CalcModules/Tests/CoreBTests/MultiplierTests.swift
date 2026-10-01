import Testing
@testable import CoreB

@Suite struct MultiplierTests {
    @Test func multiplies() { #expect(Multiplier().multiply(2, 3) == 6) }
    @Test func even() { #expect(Multiplier().isEven(4)); #expect(!Multiplier().isEven(3)) }
}
