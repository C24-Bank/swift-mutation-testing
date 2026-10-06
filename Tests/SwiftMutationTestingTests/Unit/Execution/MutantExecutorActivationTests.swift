import Foundation
import Testing

@testable import SwiftMutationTesting

@Suite("MutantExecutor — activation")
struct MutantExecutorActivationTests {

    @Test("Given the suite passes and the mutated code ran, when executed, then the mutant survived")
    func aSurvivorWhoseCodeRanSurvives() async throws {
        let dir = try FileHelpers.makeTemporaryDirectory()
        defer { FileHelpers.cleanup(dir) }

        let results = try await execute(in: dir, launcher: MarkerWritingLauncher(full: .survived(writesMarker: true)))

        #expect(results.map(\.status) == [.survived])
        #expect(results.map(\.activated) == [true])
    }

    @Test("Given the suite passes and the mutated code never ran, when executed, then the mutant has no coverage")
    func aSurvivorWhoseCodeNeverRanHasNoCoverage() async throws {
        let dir = try FileHelpers.makeTemporaryDirectory()
        defer { FileHelpers.cleanup(dir) }

        let results = try await execute(in: dir, launcher: MarkerWritingLauncher(full: .survived(writesMarker: false)))

        #expect(results.map(\.status) == [.noCoverage])
        #expect(results.map(\.activated) == [false])
    }

    @Test("Given a kill without activation that repeats, when executed, then it stands, unactivated")
    func aRepeatedKillWithoutActivationIsKeptAndFlagged() async throws {
        let dir = try FileHelpers.makeTemporaryDirectory()
        defer { FileHelpers.cleanup(dir) }
        let launcher = MarkerWritingLauncher(full: .killed(by: "flaky()", writesMarker: true), activates: ["m1"])

        let results = try await execute(in: dir, mutantIDs: ["m0", "m1"], launcher: launcher)
            .sorted { $0.descriptor.id < $1.descriptor.id }

        #expect(results.map(\.status) == [.killed(by: "flaky()"), .killed(by: "flaky()")])
        #expect(results.map(\.activated) == [false, true])
        #expect(await launcher.fullRuns(of: "m0") == 2)
    }

    @Test("Given a kill without activation that passes when run again, when executed, then the second run decides")
    func aFlakyKillIsJudgedByTheRerun() async throws {
        let dir = try FileHelpers.makeTemporaryDirectory()
        defer { FileHelpers.cleanup(dir) }
        let launcher = MarkerWritingLauncher(
            full: .killed(by: "flaky()", writesMarker: false), rerun: .survived(writesMarker: false)
        )

        let results = try await execute(in: dir, launcher: launcher)

        #expect(results.map(\.status) == [.noCoverage])
        #expect(results.map(\.activated) == [false])
        #expect(await launcher.fullRuns(of: "m0") == 2)
    }

    @Test("Given a kill whose mutated code ran, when executed, then it is not run again")
    func anActivatedKillRunsOnce() async throws {
        let dir = try FileHelpers.makeTemporaryDirectory()
        defer { FileHelpers.cleanup(dir) }
        let launcher = MarkerWritingLauncher(full: .killed(by: "check()", writesMarker: true))

        let results = try await execute(in: dir, launcher: launcher)

        #expect(results.map(\.status) == [.killed(by: "check()")])
        #expect(await launcher.fullRuns(of: "m0") == 1)
    }

    @Test("Given only the targeted run reached the mutated code, when executed, then the mutant counts as activated")
    func activationInEitherRunCounts() async throws {
        let dir = try FileHelpers.makeTemporaryDirectory()
        defer { FileHelpers.cleanup(dir) }
        let launcher = MarkerWritingLauncher(
            full: .survived(writesMarker: false), targeted: .survived(writesMarker: true)
        )

        let results = try await execute(in: dir, withSuite: true, launcher: launcher)

        #expect(results.map(\.status) == [.survived])
        #expect(results.map(\.activated) == [true])
    }

    @Test("Given a verdict and its activation in the cache, when executed again, then both come back from it")
    func cachedResultsKeepTheirActivation() async throws {
        let dir = try FileHelpers.makeTemporaryDirectory()
        defer { FileHelpers.cleanup(dir) }
        _ = try await execute(
            in: dir, noCache: false, launcher: MarkerWritingLauncher(full: .survived(writesMarker: false))
        )

        let results = try await execute(
            in: dir, noCache: false, launcher: MarkerWritingLauncher(full: .survived(writesMarker: true))
        )

        #expect(results.map(\.status) == [.noCoverage])
        #expect(results.map(\.activated) == [false])
        #expect(results.map(\.testDuration) == [0])
    }

    // MARK: - Helpers

    private func execute(
        in dir: URL,
        withSuite: Bool = false,
        noCache: Bool = true,
        mutantIDs: [String] = ["m0"],
        launcher: MarkerWritingLauncher
    ) async throws -> [ExecutionResult] {
        let sourceFile = dir.appendingPathComponent("Foo.swift")
        if !FileManager.default.fileExists(atPath: sourceFile.path) {
            try "let x = true".write(to: sourceFile, atomically: true, encoding: .utf8)
        }
        if withSuite {
            let tests = dir.appendingPathComponent("Tests/PkgTests")
            try FileManager.default.createDirectory(at: tests, withIntermediateDirectories: true)
            try "@Suite struct FooTests {}".write(
                to: tests.appendingPathComponent("FooTests.swift"), atomically: true, encoding: .utf8
            )
        }

        return try await MutantExecutor(
            configuration: makeRunnerConfiguration(projectPath: dir.path, projectType: .spm, noCache: noCache),
            launcher: launcher
        ).execute(
            makeRunnerInput(
                projectPath: dir.path, projectType: .spm, noCache: noCache,
                schematizedFiles: [SchematizedFile(originalPath: sourceFile.path, schematizedContent: "let x = false")],
                mutants: mutantIDs.enumerated().map {
                    makeMutantDescriptor(id: $1, filePath: sourceFile.path, utf8Offset: $0, isSchematizable: true)
                }
            )
        )
    }
}
