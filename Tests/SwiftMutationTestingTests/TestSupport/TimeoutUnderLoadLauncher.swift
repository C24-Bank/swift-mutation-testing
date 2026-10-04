import Foundation

@testable import SwiftMutationTesting

actor TimeoutUnderLoadLauncher: ProcessLaunching {
    private let timesOutFirst: Set<String>
    private let alwaysTimesOut: Set<String>
    private let holdFirstAttemptsUntil: Int
    private let holdRetriesUntil: Int
    private var attempts: [String: Int] = [:]
    private var inFlight = 0
    private(set) var sequence: [(id: String, attempt: Int)] = []
    private(set) var inFlightDuringRetry: [String: Int] = [:]
    private(set) var timeouts: [String: [Double]] = [:]
    private(set) var maxInFlightDuringFirstAttempts = 0

    /// `holdFirstAttemptsUntil` and `holdRetriesUntil` keep a run waiting until that many are in flight,
    /// so that an assertion on how many ran at once does not depend on how loaded the machine is.
    init(
        timesOutFirst: Set<String>,
        alwaysTimesOut: Set<String> = [],
        holdFirstAttemptsUntil: Int = 1,
        holdRetriesUntil: Int = 1
    ) {
        self.timesOutFirst = timesOutFirst
        self.alwaysTimesOut = alwaysTimesOut
        self.holdFirstAttemptsUntil = holdFirstAttemptsUntil
        self.holdRetriesUntil = holdRetriesUntil
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
        guard let id = request.additionalEnvironment["__SWIFT_MUTATION_TESTING_ACTIVE"] else {
            return (0, "")
        }

        inFlight += 1
        defer { inFlight -= 1 }

        let attempt = (attempts[id] ?? 0) + 1
        attempts[id] = attempt
        sequence.append((id: id, attempt: attempt))
        timeouts[id, default: []].append(request.timeout)
        try await hold(until: attempt > 1 ? holdRetriesUntil : holdFirstAttemptsUntil)
        if attempt > 1 {
            inFlightDuringRetry[id] = inFlight
        } else {
            maxInFlightDuringFirstAttempts = max(maxInFlightDuringFirstAttempts, inFlight)
        }

        try await Task.sleep(for: .milliseconds(20))

        if alwaysTimesOut.contains(id) || (attempt == 1 && timesOutFirst.contains(id)) {
            return (SPMResultParser.timedOutExitCode, "")
        }
        return (0, "")
    }

    func attemptCount(for id: String) -> Int {
        attempts[id] ?? 0
    }

    private func hold(until expected: Int) async throws {
        let deadline = ContinuousClock.now + .seconds(2)
        while inFlight < expected, ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(5))
        }
    }
}
