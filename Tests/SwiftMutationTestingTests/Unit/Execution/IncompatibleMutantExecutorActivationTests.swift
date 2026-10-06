import Foundation
import Testing

@testable import SwiftMutationTesting

@Suite("IncompatibleMutantExecutor — activation")
struct IncompatibleMutantExecutorActivationTests {
    private static let original = "struct Config {\n    var limit = 10 + 1\n}\n"
    private static let mutated = "struct Config {\n    var limit = 10 - 1\n}\n"
    private static let offset = 35

    @Test("Given a test that reaches the mutated initializer, when executed, then the survivor is activated")
    func aReachedSurvivorIsActivated() async throws {
        let (results, launcher) = try await execute(testRuns: [.passes(writesMarker: true)])

        #expect(results.map(\.status) == [.survived])
        #expect(results.map(\.activated) == [true])
        #expect(await launcher.builtInstrumented == [false, true])
        #expect(await launcher.testEnvironments.first?[ActivationMarker.environmentVariable] != nil)
    }

    @Test("Given no test reaches the mutated initializer, when executed, then the mutant has no coverage")
    func anUnreachedSurvivorHasNoCoverage() async throws {
        let (results, _) = try await execute(testRuns: [.passes(writesMarker: false)])

        #expect(results.map(\.status) == [.noCoverage])
        #expect(results.map(\.activated) == [false])
    }

    @Test("Given the instrumented copy does not build, when executed, then the plain mutant runs unmeasured")
    func anInstrumentedBuildFailureFallsBackToThePlainMutant() async throws {
        let (results, launcher) = try await execute(
            failsInstrumentedBuild: true, testRuns: [.passes(writesMarker: false)]
        )

        #expect(results.map(\.status) == [.survived])
        #expect(results.map(\.activated) == [nil])
        #expect(await launcher.builtInstrumented == [false, true, false])
        #expect(await launcher.testEnvironments == [[:]])
    }

    @Test("Given a kill without activation that passes when run again, when executed, then the second run decides")
    func aKillWithoutActivationIsRunAgain() async throws {
        let (results, launcher) = try await execute(
            testRuns: [.fails("flaky()", writesMarker: false), .passes(writesMarker: false)]
        )

        #expect(results.map(\.status) == [.noCoverage])
        #expect(await launcher.testEnvironments.count == 2)
    }

    @Test("Given an activated kill, when executed, then it is recorded with its activation and cached")
    func anActivatedKillIsCachedWithItsActivation() async throws {
        let dir = try FileHelpers.makeTemporaryDirectory()
        defer { FileHelpers.cleanup(dir) }

        let cacheStore = CacheStore(storePath: dir.appendingPathComponent("cache.json").path)

        _ = try await execute(in: dir, cacheStore: cacheStore, testRuns: [.fails("check()", writesMarker: true)])
        let (cached, launcher) = try await execute(in: dir, cacheStore: cacheStore, testRuns: [])

        #expect(cached.map(\.status) == [.killed(by: "check()")])
        #expect(cached.map(\.activated) == [true])
        #expect(await launcher.testEnvironments.isEmpty)
    }

    @Test("Given an Xcode project, when executed, then the marker path reaches the test runner")
    func xcodeTestsReceiveTheMarkerThroughTheTestRunnerPrefix() async throws {
        let (results, launcher) = try await execute(
            projectType: .xcode(scheme: "App", destination: "platform=macOS"),
            testRuns: [.passes(writesMarker: true)]
        )

        let environment = try #require(await launcher.testEnvironments.first)
        #expect(environment.keys.sorted() == ["TEST_RUNNER_" + ActivationMarker.environmentVariable])
        #expect(results.map(\.activated) == [true])
    }

    @Test("Given an Xcode kill without activation that passes when run again, when executed, then the rerun decides")
    func anXcodeKillWithoutActivationIsRunAgain() async throws {
        let (results, launcher) = try await execute(
            projectType: .xcode(scheme: "App", destination: "platform=macOS"),
            testRuns: [.fails("flaky()", writesMarker: false), .passes(writesMarker: false)]
        )

        #expect(results.map(\.status) == [.noCoverage])
        #expect(await launcher.testEnvironments.count == 2)
    }

    // MARK: - Helpers

    private func execute(
        projectType: ProjectType = .spm,
        failsInstrumentedBuild: Bool = false,
        testRuns: [ActivationScriptLauncher.TestRun]
    ) async throws -> ([ExecutionResult], ActivationScriptLauncher) {
        let dir = try FileHelpers.makeTemporaryDirectory()
        defer { FileHelpers.cleanup(dir) }
        return try await execute(
            in: dir, noCache: true, projectType: projectType, failsInstrumentedBuild: failsInstrumentedBuild,
            testRuns: testRuns
        )
    }

    private func execute(
        in dir: URL,
        noCache: Bool = false,
        cacheStore: CacheStore? = nil,
        projectType: ProjectType = .spm,
        failsInstrumentedBuild: Bool = false,
        testRuns: [ActivationScriptLauncher.TestRun]
    ) async throws -> ([ExecutionResult], ActivationScriptLauncher) {
        let sources = dir.appendingPathComponent("Sources/Lib")
        try FileManager.default.createDirectory(at: sources, withIntermediateDirectories: true)
        let file = sources.appendingPathComponent("Config.swift")
        try Self.original.write(to: file, atomically: true, encoding: .utf8)

        let launcher = ActivationScriptLauncher(
            mutatedFile: "Sources/Lib/Config.swift", failsInstrumentedBuild: failsInstrumentedBuild, testRuns: testRuns
        )
        let executor = IncompatibleMutantExecutor(
            deps: ExecutionDeps(
                launcher: launcher,
                cacheStore: cacheStore ?? CacheStore(storePath: dir.appendingPathComponent("cache.json").path),
                reporter: MockProgressReporter(),
                counter: MutationCounter(total: 1),
                killerTestFileResolver: KillerTestFileResolver(testFilePaths: [], projectPath: dir.path)
            ),
            sandboxFactory: SandboxFactory()
        )
        let pool = makeSimulatorPool()
        try await pool.setUp()

        let results = try await executor.execute(
            [
                makeMutantDescriptor(
                    filePath: file.path, line: 2, column: 20, utf8Offset: Self.offset,
                    mutatedSourceContent: Self.mutated
                )
            ],
            configuration: makeRunnerConfiguration(projectPath: dir.path, projectType: projectType, noCache: noCache),
            pool: pool
        )
        return (results, launcher)
    }
}
