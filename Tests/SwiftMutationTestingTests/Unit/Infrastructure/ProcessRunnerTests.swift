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

    @Test("Given a stop rule, when the process prints a marker, then it is stopped and reports the rule's exit code")
    func aMarkerStopsTheProcessEarly() async throws {
        let runner = ProcessRunner(onTimeout: { pid in kill(-pid, SIGTERM) })
        let script = "echo \"Test Case '-[SuiteTests aCheck]' failed (0.001 seconds).\"; sleep 30"
        let start = ContinuousClock.now

        let result = try await runner.launchCapturing(shell(script, timeout: 20).stopping(at: .firstTestFailure))

        #expect(result.exitCode == 1)
        #expect(result.output.contains("aCheck"))
        #expect(ContinuousClock.now - start < .seconds(5))
    }

    @Test("Given a stop rule, when the marker arrives split across two writes, then it is still seen")
    func aMarkerSplitAcrossWritesIsStillSeen() async throws {
        let runner = ProcessRunner(onTimeout: { pid in kill(-pid, SIGTERM) })
        let script =
            "printf \"Test Case '-[SuiteTests aCheck]' fai\"; sleep 0.4; printf \"led (0.1 seconds).\\n\"; sleep 30"

        let result = try await runner.launchCapturing(shell(script, timeout: 20).stopping(at: .firstTestFailure))

        #expect(result.exitCode == 1)
    }

    @Test("Given a stop rule, when no marker is printed, then the process runs to its own end")
    func noMarkerLetsTheProcessFinish() async throws {
        let runner = ProcessRunner(onTimeout: { pid in kill(-pid, SIGTERM) })

        let request = shell("echo all good; exit 3", timeout: 20).stopping(at: .firstTestFailure)

        let result = try await runner.launchCapturing(request)

        #expect(result.exitCode == 3)
        #expect(result.output == "all good\n")
    }

    @Test("Given a stop rule and a process that never prints a marker, when the timeout passes, then it is a timeout")
    func theTimeoutStillAppliesUnderAStopRule() async throws {
        let runner = ProcessRunner(onTimeout: { pid in kill(-pid, SIGTERM) })

        let request = shell("echo waiting; sleep 30", timeout: 0.5).stopping(at: .firstTestFailure)

        let result = try await runner.launchCapturing(request)

        #expect(result.exitCode == -1)
    }

    private func shell(_ script: String, timeout: Double) -> ProcessRequest {
        ProcessRequest(
            executableURL: URL(fileURLWithPath: "/bin/sh"),
            arguments: ["-c", script],
            environment: nil,
            additionalEnvironment: [:],
            workingDirectoryURL: URL(fileURLWithPath: "/tmp"),
            timeout: timeout
        )
    }
}
