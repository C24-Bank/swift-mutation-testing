import CryptoKit
import Foundation

enum SupportDeclarations {
    static func suffix(for path: String) -> String {
        SHA256.hash(data: Data(path.utf8)).prefix(4).map { String(format: "%02x", $0) }.joined()
    }

    static func identifier(for path: String) -> String {
        "__swiftMutationTestingID_\(suffix(for: path))"
    }

    static func activationCall(for path: String) -> String {
        "__SwiftMutationTesting_\(suffix(for: path)).activated()"
    }

    static func perFile(for path: String) -> String {
        let suffix = suffix(for: path)
        return """
            internal import Foundation

            @usableFromInline
            internal enum __SwiftMutationTesting_\(suffix) {
                @usableFromInline nonisolated static let id: String =
                    ProcessInfo.processInfo.environment["__SWIFT_MUTATION_TESTING_ACTIVE"] ?? ""
                nonisolated(unsafe) static var activationRecorded = false

                @usableFromInline nonisolated static func activated() {
                    guard
                        !activationRecorded,
                        let path = ProcessInfo.processInfo.environment["__SWIFT_MUTATION_TESTING_ACTIVATION_FILE"]
                    else { return }
                    activationRecorded = true
                    FileManager.default.createFile(atPath: path, contents: nil)
                }
            }

            @usableFromInline nonisolated internal var __swiftMutationTestingID_\(suffix): String {
                __SwiftMutationTesting_\(suffix).id
            }
            """
    }
}
