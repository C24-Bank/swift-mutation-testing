import Foundation
import Testing

@testable import SwiftMutationTesting

@Suite("TimeoutEscalation")
struct TimeoutEscalationTests {

    @Test("Given an armed escalation, when the process terminates, then descendants die without waiting")
    func killsDescendantsImmediatelyOnTermination() async throws {
        let target = try spawnGroupLeader()
        defer { stop(target) }
        let child = try spawnSleeper()
        defer { stop(child) }

        let escalation = TimeoutEscalation(gracePeriod: 30)
        escalation.arm(pid: target.pid, descendants: [child.pid])

        escalation.processTerminated()
        await exit(of: child)

        #expect(wasKilled(child), "the descendant should not have outlived the run")
    }

    @Test("Given the grace period elapses, when the process is still alive, then descendants are killed")
    func killsDescendantsWhenGracePeriodElapses() async throws {
        let target = try spawnGroupLeader()
        defer { stop(target) }
        let child = try spawnSleeper()
        defer { stop(child) }

        let escalation = TimeoutEscalation(gracePeriod: 0.2)
        escalation.arm(pid: target.pid, descendants: [child.pid])

        await exit(of: child)
        await exit(of: target)
        withExtendedLifetime(escalation) {}

        #expect(wasKilled(child), "the descendant should have been killed once the grace period ran out")
        #expect(wasKilled(target), "the process group should have been killed too")
    }

    @Test("Given termination before the grace period, when it would have elapsed, then nothing is signalled again")
    func doesNotSignalAfterTermination() async throws {
        let target = try spawnGroupLeader()
        defer { stop(target) }
        let child = try spawnSleeper()
        defer { stop(child) }

        let escalation = TimeoutEscalation(gracePeriod: 0.3)
        escalation.arm(pid: target.pid, descendants: [child.pid])
        escalation.processTerminated()

        let later = try spawnSleeper()
        defer { stop(later) }

        try await Task.sleep(for: .milliseconds(600))

        #expect(later.isRunning, "a process started after termination must not be reached")
        #expect(target.isRunning, "the group must not be killed once the process has terminated")
    }

    @Test("Given no descendants, when the process terminates, then nothing happens")
    func handlesEmptySnapshot() throws {
        let target = try spawnGroupLeader()
        defer { stop(target) }

        let escalation = TimeoutEscalation(gracePeriod: 0.1)
        escalation.arm(pid: target.pid, descendants: [])

        escalation.processTerminated()

        #expect(target.isRunning)
    }

    // MARK: - Private

    private func spawnGroupLeader() throws -> Sleeper {
        let sleeper = try spawnSleeper()
        setpgid(sleeper.pid, sleeper.pid)

        try #require(
            getpgid(sleeper.pid) == sleeper.pid,
            "refusing to signal a group the test runner belongs to"
        )

        return sleeper
    }

    private func exit(of sleeper: Sleeper) async {
        await withCheckedContinuation { continuation in
            DispatchQueue.global().async {
                sleeper.exited.wait()
                continuation.resume()
            }
        }
    }

    private func stop(_ sleeper: Sleeper) {
        if sleeper.process.isRunning {
            kill(sleeper.pid, SIGKILL)
        }
    }

    private func wasKilled(_ sleeper: Sleeper) -> Bool {
        sleeper.process.terminationReason == .uncaughtSignal && sleeper.process.terminationStatus == SIGKILL
    }

    private struct Sleeper: @unchecked Sendable {
        let process: Process
        let exited: DispatchSemaphore

        var pid: Int32 { process.processIdentifier }
        var isRunning: Bool { process.isRunning }
    }

    private func spawnSleeper() throws -> Sleeper {
        let process = Process()
        let exited = DispatchSemaphore(value: 0)
        process.executableURL = URL(fileURLWithPath: "/bin/sleep")
        process.arguments = ["30"]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        process.terminationHandler = { _ in exited.signal() }
        try process.run()
        return Sleeper(process: process, exited: exited)
    }
}
