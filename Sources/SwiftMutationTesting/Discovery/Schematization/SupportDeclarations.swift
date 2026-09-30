enum SupportDeclarations {
    static let perFile = """
        import Foundation

        private enum __SwiftMutationTesting {
            nonisolated static let id: String =
                ProcessInfo.processInfo.environment["__SWIFT_MUTATION_TESTING_ACTIVE"] ?? ""
        }

        nonisolated private var __swiftMutationTestingID: String { __SwiftMutationTesting.id }
        """
}
