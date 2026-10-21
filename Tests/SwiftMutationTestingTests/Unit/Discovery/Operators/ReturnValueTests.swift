import Testing

@testable import SwiftMutationTesting

@Suite("ReturnValue")
struct ReturnValueTests {
    private let op = ReturnValue()

    private func mutated(_ code: String) -> [String] {
        op.mutations(in: makeParsedSource(code)).map(\.description)
    }

    @Test("Given a Bool return, when visited, then it becomes true and false")
    func boolReturn() {
        #expect(mutated("func f() -> Bool { return a > b }") == ["return a > b → return true", "return a > b → return false"])
    }

    @Test("Given a returned Bool literal, when visited, then only the other literal is used")
    func boolLiteralReturn() {
        #expect(mutated("func f() -> Bool { return true }") == ["return true → return false"])
    }

    @Test("Given optional, array, set and dictionary returns, when visited, then each gets its empty value")
    func emptyValues() {
        let code = """
            func a() -> Int? { return x }
            func b() -> [Int] { return xs }
            func c() -> Set<Int> { return s }
            func d() -> [String: Int] { return m }
            """
        #expect(mutated(code) == ["return x → return nil", "return xs → return []", "return s → return []", "return m → return [:]"])
    }

    @Test("Given an implicit return in a function and a computed property, when visited, then it is mutated")
    func implicitReturns() {
        let code = """
            func f() -> Bool { isOn }
            var items: [Int] { all.filter { $0 > 0 } }
            """
        #expect(mutated(code) == ["return isOn → return true", "return isOn → return false", "return all.filter { $0 > 0 } → return []"])
    }

    @Test("Given returns inside closures, other types, initializers and nil, when visited, then nothing is mutated")
    func skippedReturns() {
        let code = """
            func f() -> [Int] { xs.map { return $0 + 1 } }
            func g() -> Int { return 1 }
            func h() -> String? { return nil }
            init?() { return nil }
            """
        #expect(mutated(code) == ["return xs.map { return $0 + 1 } → return []"])
    }
}
