import Foundation
import Testing

extension Trait where Self == ConditionTrait {
    /// Keeps a suite that runs the mutation pipeline itself out of a mutation run of this repository.
    ///
    /// Inside a mutant's test run `__SWIFT_MUTATION_TESTING_ACTIVE` names the mutant; such a suite would
    /// build and test a fixture for every one of the thousand mutants, at a cost no verdict pays back. The
    /// baseline run sets the variable empty, so the suites still run there and in a plain `swift test`.
    static var notInsideAMutationRun: Self {
        .disabled(
            if: ProcessInfo.processInfo.environment["__SWIFT_MUTATION_TESTING_ACTIVE"]?.isEmpty == false,
            "a mutation run does not nest another"
        )
    }
}
