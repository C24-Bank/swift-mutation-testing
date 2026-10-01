import Foundation

@testable import SwiftMutationTesting

actor TwoLibraryBundleLauncher: ProcessLaunching {
    private let xctestOutput: String
    private let xctestExitCode: Int32
    private let swiftTestingOutput: String
    private let swiftTestingExitCode: Int32
    private let swiftTestingDelay: Duration
    private let probePasses: Bool

    init(
        xctestOutput: String,
        xctestExitCode: Int32 = 0,
        swiftTestingOutput: String,
        swiftTestingExitCode: Int32 = 0,
        swiftTestingDelay: Duration = .zero,
        probePasses: Bool = false
    ) {
        self.xctestOutput = xctestOutput
        self.xctestExitCode = xctestExitCode
        self.swiftTestingOutput = swiftTestingOutput
        self.swiftTestingExitCode = swiftTestingExitCode
        self.swiftTestingDelay = swiftTestingDelay
        self.probePasses = probePasses
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
        request.recordActivation()
        if request.arguments.first == "build" {
            let macOS = request.workingDirectoryURL
                .appendingPathComponent(".build/out/Products/Debug/PkgTests.xctest/Contents/MacOS")
            try FileManager.default.createDirectory(at: macOS, withIntermediateDirectories: true)
            FileManager.default.createFile(atPath: macOS.appendingPathComponent("PkgTests").path, contents: Data())
            return (0, "")
        }

        let isProbe = request.additionalEnvironment["__SWIFT_MUTATION_TESTING_ACTIVE"] == ""

        if request.arguments.first == "xctest" {
            return probePasses && isProbe
                ? (0, "Executed 3 tests, with 0 failures (0 unexpected) in 0.010 (0.011) seconds")
                : (xctestExitCode, xctestOutput)
        }

        if request.executableURL.lastPathComponent == "swiftpm-testing-helper" {
            try await Task.sleep(for: swiftTestingDelay)
            return probePasses && isProbe
                ? (0, "✔ Test run with 3 tests in 1 suite passed after 0.1 seconds.")
                : (swiftTestingExitCode, swiftTestingOutput)
        }

        return (0, "")
    }
}
