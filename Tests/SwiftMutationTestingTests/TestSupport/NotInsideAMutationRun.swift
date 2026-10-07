import Foundation
import Testing

extension Trait where Self == ConditionTrait {
    static var notInsideAMutationRun: Self {
        .disabled(
            if: ProcessInfo.processInfo.environment["__SWIFT_MUTATION_TESTING_ACTIVE"]?.isEmpty == false,
            "a mutation run does not nest another"
        )
    }
}
