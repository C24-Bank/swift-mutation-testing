import Foundation
import Testing

@testable import SwiftMutationTesting

@Suite("OrphanedProcessReaper")
struct OrphanedProcessReaperTests {

    @Test("Given an argument inside a sandbox, when searched, then the sandbox name is found")
    func findsTheSandboxInAPath() {
        let name = "xmr-4242-\(UUID().uuidString)"
        let arguments = [
            "/usr/libexec/helper", "--test-bundle-path", "/tmp/swift-mutation-testing/\(name)/Tests.xctest",
        ]

        #expect(OrphanedProcessReaper.sandboxName(in: arguments) == name)
    }

    @Test("Given arguments with no sandbox, when searched, then nothing is found")
    func findsNothingOutsideASandbox() {
        let arguments = ["/bin/sleep", "30", "/tmp/xmr-\(UUID().uuidString)/legacy", "/tmp/xmr-notes"]

        #expect(OrphanedProcessReaper.sandboxName(in: arguments) == nil)
    }

    @Test("Given a process in the sandbox of a dead run, when reaped, then it and its descendants are killed")
    func killsAProcessWhoseOwnerIsGone() {
        let recorder = RecordingKill()
        let reaper = reaper(
            arguments: [500: ["helper", "/tmp/xmr-4242-\(UUID().uuidString)/bundle"]],
            alive: false,
            descendants: [500: [501, 502]],
            kill: recorder
        )

        #expect(reaper.reap() == [500])
        #expect(recorder.recorded.map(\.pid) == [501, 502, 500])
        #expect(recorder.recorded.allSatisfy { $0.signal == SIGKILL })
    }

    @Test("Given a process in the sandbox of a live run, when reaped, then it is left alone")
    func sparesAProcessWhoseOwnerIsAlive() {
        let recorder = RecordingKill()
        let reaper = reaper(
            arguments: [500: ["helper", "/tmp/xmr-4242-\(UUID().uuidString)/bundle"]],
            alive: true,
            kill: recorder
        )

        #expect(reaper.reap().isEmpty)
        #expect(recorder.recorded.isEmpty)
    }

    @Test("Given a process in this run's own sandbox, when reaped, then it is left alone")
    func sparesProcessesOfTheCurrentRun() {
        let recorder = RecordingKill()
        let reaper = reaper(
            arguments: [500: ["helper", "/tmp/\(SandboxName.make())/bundle"]],
            alive: false,
            kill: recorder
        )

        #expect(reaper.reap().isEmpty)
        #expect(recorder.recorded.isEmpty)
    }

    @Test("Given processes whose arguments cannot be read or name no sandbox, when reaped, then none is killed")
    func sparesProcessesItCannotPlace() {
        let recorder = RecordingKill()
        let reaper = reaper(
            arguments: [500: ["/bin/sleep", "30"]],
            processes: [500, 600, getpid()],
            alive: false,
            kill: recorder
        )

        #expect(reaper.reap().isEmpty)
        #expect(recorder.recorded.isEmpty)
    }

    @Test("Given a real process left running from a dead run's sandbox, when reaped, then it dies")
    func reapsARealOrphan() async throws {
        let baseDir = try FileHelpers.makeTemporaryDirectory()
        defer { FileHelpers.cleanup(baseDir) }

        let finished = Process()
        finished.executableURL = URL(fileURLWithPath: "/usr/bin/true")
        try finished.run()
        finished.waitUntilExit()
        let deadRun = finished.processIdentifier
        let reapDeadline = ContinuousClock.now + .seconds(5)
        while kill(deadRun, 0) == 0, ContinuousClock.now < reapDeadline {
            try await Task.sleep(for: .milliseconds(20))
        }

        let sandbox = baseDir.appendingPathComponent(SandboxName.make(pid: deadRun))
        try FileManager.default.createDirectory(at: sandbox, withIntermediateDirectories: true)
        let file = sandbox.appendingPathComponent("output.log")
        FileManager.default.createFile(atPath: file.path, contents: nil)

        let orphan = Process()
        orphan.executableURL = URL(fileURLWithPath: "/usr/bin/tail")
        orphan.arguments = ["-f", file.path]
        orphan.standardOutput = FileHandle.nullDevice
        try orphan.run()
        defer { if orphan.isRunning { orphan.terminate() } }

        try await Task.sleep(for: .milliseconds(200))

        var reaper = OrphanedProcessReaper()
        let pid = orphan.processIdentifier
        reaper.processes = { [pid] }

        let reaped = reaper.reap()
        #expect(reaped == [pid] || !orphan.isRunning)

        let deadline = ContinuousClock.now + .seconds(5)
        while orphan.isRunning, ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(50))
        }

        #expect(!orphan.isRunning, "the orphan outlived the sweep")
    }

    // MARK: - Private

    private func reaper(
        arguments: [pid_t: [String]],
        processes: [pid_t]? = nil,
        alive: Bool,
        descendants: [pid_t: [pid_t]] = [:],
        kill: RecordingKill
    ) -> OrphanedProcessReaper {
        OrphanedProcessReaper(
            processes: { processes ?? Array(arguments.keys) },
            arguments: { arguments[$0] },
            descendants: { descendants[$0] ?? [] },
            isOwnerAlive: { _ in alive },
            kill: kill.asKill
        )
    }
}
