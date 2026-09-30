import Foundation

struct ActivationMarker: Sendable {
    static let environmentVariable = "__SWIFT_MUTATION_TESTING_ACTIVATION_FILE"
    static let directoryName = ".xmr-activation"

    let path: String

    init(for mutantID: String, in sandbox: Sandbox) {
        let directory = sandbox.rootURL.appendingPathComponent(Self.directoryName)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        path = directory.appendingPathComponent("\(mutantID)-\(UUID().uuidString)").path
    }

    func wasWritten() -> Bool {
        defer { try? FileManager.default.removeItem(atPath: path) }
        return FileManager.default.fileExists(atPath: path)
    }
}
