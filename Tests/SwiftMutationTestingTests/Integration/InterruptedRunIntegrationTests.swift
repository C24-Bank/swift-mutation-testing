import Foundation
import Synchronization
import Testing

@testable import SwiftMutationTesting

@Suite(.tags(.integration), .serialized, .notInsideAMutationRun)
struct InterruptedRunIntegrationTests {
    @Test(
        "Given the tool interrupted by SIGINT after its first verdicts, when run again, then nothing reached is lost or rerun"
    )
    func aSigintLosesNoVerdict() async throws {
        let binary = try #require(Self.builtTool(), "the swift-mutation-testing executable was not built")
        let fixture = try FixtureCopy.make("CalcLibrary")
        defer { fixture.remove() }
        let root = fixture.url.path
        let planPath = fixture.url.appendingPathComponent("plan.json").path
        let planned = await SwiftMutationTesting.run(
            args: ["plan", root, "--output", planPath, "--quiet", "--operator-tier", "experimental"]
        )
        #expect(planned == .success)
        let plan = try PlanStore().read(from: planPath)
        let journalPath = PlanJournal.path(projectPath: root, planSha256: try PlanStore.sha256(of: plan), shard: nil)

        let child = Process()
        child.executableURL = binary
        child.arguments = ["run", root, "--plan", planPath, "--no-cache", "--quiet", "--concurrency", "1"]
        child.standardOutput = FileHandle.nullDevice
        child.standardError = FileHandle.nullDevice
        let exited = Mutex(false)
        child.terminationHandler = { _ in exited.withLock { $0 = true } }
        try child.run()

        let deadline = ContinuousClock.now + .seconds(300)
        while PlanJournal.entries(at: journalPath).isEmpty, !exited.withLock({ $0 }), ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(20))
        }
        child.interrupt()
        while !exited.withLock({ $0 }), ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(20))
        }
        try #require(exited.withLock { $0 }, "the interrupted run did not exit")

        let reached = PlanJournal.entries(at: journalPath)
        #expect(child.terminationReason == .exit && child.terminationStatus == 1, "the run ended before the signal")
        #expect(!reached.isEmpty)
        #expect(reached.count < plan.mutants.count)

        let launcher = CountingLauncher(wrapping: SPMProcessLauncher())
        let reportPath = fixture.url.appendingPathComponent("r.json").path
        let resumed = await SwiftMutationTesting.run(
            args: ["run", root, "--plan", planPath, "--no-cache", "--quiet", "--output", reportPath],
            launcher: launcher
        )

        #expect(resumed == .success)
        let tested = Set(
            await launcher.requests.compactMap { $0.additionalEnvironment["__SWIFT_MUTATION_TESTING_ACTIVE"] }
                .filter { !$0.isEmpty }
        )
        let expected = Set(
            plan.mutants.enumerated().filter { reached[$0.element.fingerprint] == nil }.map {
                MutantID.make(index: $0.offset)
            }
        )
        #expect(tested == expected)
        let report = try JSONDecoder().decode(
            MutationReportPayload.self, from: Data(contentsOf: URL(fileURLWithPath: reportPath))
        )
        let statuses = Dictionary(
            uniqueKeysWithValues: report.files.values.flatMap(\.mutants).map { ($0.fingerprint, $0.status) }
        )
        #expect(statuses.count == plan.mutants.count)
        for (fingerprint, entry) in reached {
            #expect(statuses[fingerprint] == entry.status.mutationReportStatus)
        }
        #expect(!FileManager.default.fileExists(atPath: journalPath))
    }

    static func builtTool() -> URL? {
        let build = URL(filePath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent()
            .appending(path: ".build")
        return ["out/Products/Debug", "debug", "arm64-apple-macosx/debug", "x86_64-apple-macosx/debug"]
            .map { build.appending(path: $0).appending(path: "swift-mutation-testing") }
            .first { FileManager.default.isExecutableFile(atPath: $0.path) }
    }
}
