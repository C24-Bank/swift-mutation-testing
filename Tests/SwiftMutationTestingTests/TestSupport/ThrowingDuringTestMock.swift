import Foundation

@testable import SwiftMutationTesting

actor ThrowingDuringTestMock: ProcessLaunching {
    private let throwingOnTestCall: Int
    private var testCallCount = 0

    init(throwingOnTestCall: Int = 2) {
        self.throwingOnTestCall = throwingOnTestCall
    }

    func launch(
        executableURL: URL,
        arguments: [String],
        workingDirectoryURL: URL,
        timeout: Double
    ) async throws -> Int32 { 0 }

    func launchCapturing(
        _ request: ProcessRequest
    ) async throws -> (exitCode: Int32, output: String) {
        request.recordActivation()
        if request.arguments.first == "test" {
            testCallCount += 1
            if testCallCount >= throwingOnTestCall {
                throw CocoaError(.fileReadNoSuchFile)
            }
        }
        return (0, "")
    }
}
