import Foundation

@testable import SwiftMutationTesting

actor TwoLibraryBundleLauncher: ProcessLaunching {
    private let xctestOutput: String
    private let xctestExitCode: Int32
    private let swiftTestingOutput: String
    private let swiftTestingExitCode: Int32
    private let swiftTestingDelay: Duration

    init(
        xctestOutput: String,
        xctestExitCode: Int32 = 0,
        swiftTestingOutput: String,
        swiftTestingExitCode: Int32 = 0,
        swiftTestingDelay: Duration = .zero
    ) {
        self.xctestOutput = xctestOutput
        self.xctestExitCode = xctestExitCode
        self.swiftTestingOutput = swiftTestingOutput
        self.swiftTestingExitCode = swiftTestingExitCode
        self.swiftTestingDelay = swiftTestingDelay
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
            return (xctestExitCode, xctestOutput)
        }

        if request.executableURL.lastPathComponent == "swiftpm-testing-helper" {
            try await Task.sleep(for: swiftTestingDelay)
            return (swiftTestingExitCode, swiftTestingOutput)
        }

        return (0, "")
    }
}
