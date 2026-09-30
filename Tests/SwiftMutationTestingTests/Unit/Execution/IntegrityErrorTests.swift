import Testing

@testable import SwiftMutationTesting

@Suite("IntegrityError")
struct IntegrityErrorTests {
    @Test("Given one mutant not applied, when described, then the message names it and says the run stopped")
    func oneMutantNotApplied() {
        let message = IntegrityError.mutantsNotApplied(ids: ["m0"]).errorDescription

        #expect(message?.hasPrefix("1 mutant was not applied to the sandbox: m0.") == true)
        #expect(message?.contains("The run is stopped") == true)
    }

    @Test("Given many mutants not applied, when described, then ten are listed and the rest counted")
    func manyMutantsNotApplied() {
        let ids = (0 ..< 12).map { "m\($0)" }

        let message = IntegrityError.mutantsNotApplied(ids: ids).errorDescription

        let listed = "m0, m1, m2, m3, m4, m5, m6, m7, m8, m9 and 2 more"
        #expect(message?.hasPrefix("12 mutants were not applied to the sandbox: \(listed).") == true)
    }

    @Test(
        "Given a schema or support problem, when described, then the message names the file",
        arguments: [
            (IntegrityError.schemaNotApplied(path: "/p/Foo.swift"), "identical to the original"),
            (.supportMissing(path: "/p/Foo.swift"), "does not declare __swiftMutationTestingID"),
        ]
    )
    func fileProblemsNameTheFile(error: IntegrityError, fragment: String) {
        #expect(error.errorDescription?.contains("/p/Foo.swift") == true)
        #expect(error.errorDescription?.contains(fragment) == true)
    }
}
