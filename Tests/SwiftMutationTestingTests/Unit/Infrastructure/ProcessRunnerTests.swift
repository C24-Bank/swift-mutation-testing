import Foundation
import Testing

@testable import SwiftMutationTesting

@Suite("ProcessRunner")
struct ProcessRunnerTests {

    @Test("Given the capture file cannot be read back, when the process ends, then the output is empty")
    func anUnreadableCaptureYieldsEmptyOutput() async throws {
        struct Unreadable: Error {}

        let runner = ProcessRunner(onTimeout: { _ in }, readCapturedOutput: { _ in throw Unreadable() })

        let result = try await runner.launchCapturing(echo("hello"))

        #expect(result.exitCode == 0)
        #expect(result.output == "")
    }

    @Test("Given the capture file reads back, when the process ends, then the output is what it wrote")
    func aReadableCaptureYieldsTheOutput() async throws {
        let runner = ProcessRunner(onTimeout: { _ in })

        let result = try await runner.launchCapturing(echo("hello"))

        #expect(result.output == "hello\n")
    }

    private func echo(_ text: String) -> ProcessRequest {
        ProcessRequest(
            executableURL: URL(fileURLWithPath: "/bin/echo"),
            arguments: [text],
            environment: nil,
            additionalEnvironment: [:],
            workingDirectoryURL: URL(fileURLWithPath: "/tmp"),
            timeout: 10
        )
    }
}
