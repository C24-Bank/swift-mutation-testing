import Testing

@testable import SwiftMutationTesting

@Suite("MutantExecutor — observed activation")
struct ObservedActivationTests {

    @Test("Given kills and at least one activation, when checked, then the run goes on")
    func killsWithSomeActivationPass() throws {
        try MutantExecutor.requireObservedActivation(in: [
            makeExecutionResult(status: .killed(by: "t"), activated: false),
            makeExecutionResult(status: .survived, activated: true),
        ])
    }

    @Test("Given no kills and no activation, when checked, then the run goes on with every survivor uncovered")
    func noKillsAndNoActivationPass() throws {
        try MutantExecutor.requireObservedActivation(in: [
            makeExecutionResult(status: .noCoverage, activated: false),
            makeExecutionResult(status: .timeout, activated: false),
            makeExecutionResult(status: .unviable),
        ])
    }

    @Test("Given kills and no activation anywhere, when checked, then the run stops")
    func killsWithoutAnyActivationStop() {
        #expect(throws: IntegrityError.activationNeverObserved(killed: 2)) {
            try MutantExecutor.requireObservedActivation(in: [
                makeExecutionResult(status: .killed(by: "t"), activated: false),
                makeExecutionResult(status: .killedByCrash, activated: false),
                makeExecutionResult(status: .noCoverage, activated: false),
                makeExecutionResult(status: .survived),
            ])
        }
    }

    @Test("Given only unmeasured results, when checked, then the run goes on")
    func unmeasuredResultsAreIgnored() throws {
        try MutantExecutor.requireObservedActivation(in: [
            makeExecutionResult(status: .killed(by: "t")),
            makeExecutionResult(status: .survived),
        ])
    }
}
