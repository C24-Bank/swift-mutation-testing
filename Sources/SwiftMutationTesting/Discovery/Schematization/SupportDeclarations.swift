enum SupportDeclarations {
    static let activationCall = "__SwiftMutationTesting.activated()"

    static let perFile = """
        import Foundation

        private enum __SwiftMutationTesting {
            nonisolated static let id: String =
                ProcessInfo.processInfo.environment["__SWIFT_MUTATION_TESTING_ACTIVE"] ?? ""
            nonisolated(unsafe) static var activationRecorded = false

            nonisolated static func activated() {
                guard
                    !activationRecorded,
                    let path = ProcessInfo.processInfo.environment["__SWIFT_MUTATION_TESTING_ACTIVATION_FILE"]
                else { return }
                activationRecorded = true
                FileManager.default.createFile(atPath: path, contents: nil)
            }
        }

        nonisolated private var __swiftMutationTestingID: String { __SwiftMutationTesting.id }
        """
}
