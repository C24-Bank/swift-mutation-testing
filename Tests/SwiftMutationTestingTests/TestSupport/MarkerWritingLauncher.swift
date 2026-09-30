import Foundation

@testable import SwiftMutationTesting

actor MarkerWritingLauncher: ProcessLaunching {
    struct Phase: Sendable {
        let exitCode: Int32
        let output: String
        let writesMarker: Bool

        static func survived(writesMarker: Bool) -> Phase {
            Phase(
                exitCode: 0, output: "✔ Test run with 2 tests in 1 suite passed after 0.1 seconds.",
                writesMarker: writesMarker
            )
        }

        static func killed(by test: String, writesMarker: Bool) -> Phase {
            Phase(
                exitCode: 1, output: "✘ Test \"\(test)\" failed after 0.001 seconds with 1 issue.",
                writesMarker: writesMarker
            )
        }
    }

    private let full: Phase
    private let targeted: Phase?
    private let activates: Set<String>?

    init(full: Phase, targeted: Phase? = nil, activates: Set<String>? = nil) {
        self.full = full
        self.targeted = targeted
        self.activates = activates
    }

    func launch(
        executableURL: URL,
        arguments: [String],
        workingDirectoryURL: URL,
        timeout: Double
    ) async throws -> Int32 {
        0
    }

    func launchCapturing(
        _ request: ProcessRequest
    ) async throws -> (exitCode: Int32, output: String) {
        if request.arguments.first == "build" {
            let macOS = request.workingDirectoryURL
                .appendingPathComponent(".build/out/Products/Debug/PkgTests.xctest/Contents/MacOS")
            try FileManager.default.createDirectory(at: macOS, withIntermediateDirectories: true)
            FileManager.default.createFile(atPath: macOS.appendingPathComponent("PkgTests").path, contents: Data())
            return (0, "")
        }

        if request.arguments.first == "xctest" {
            return (TestBundleInvocation.noTestsExitCode, "")
        }

        guard request.executableURL.lastPathComponent == "swiftpm-testing-helper" else { return (0, "") }

        let mutantID = request.additionalEnvironment["__SWIFT_MUTATION_TESTING_ACTIVE"] ?? ""
        if mutantID.isEmpty {
            return (0, "✔ Test run with 2 tests in 1 suite passed after 0.1 seconds.")
        }

        let isTargeted = request.arguments.contains("--filter")
        let phase = isTargeted ? (targeted ?? full) : full

        let writesMarker = activates.map { $0.contains(mutantID) } ?? phase.writesMarker
        if writesMarker, let path = request.additionalEnvironment[ActivationMarker.environmentVariable] {
            FileManager.default.createFile(atPath: path, contents: nil)
        }

        return (phase.exitCode, phase.output)
    }
}
