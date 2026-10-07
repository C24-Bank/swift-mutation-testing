import Foundation
import Testing

@testable import SwiftMutationTesting

@Suite("ResultRecorder")
struct ResultRecorderTests {

    @Test("Given a verdict, when it is recorded, then it is logged, cached, counted and reported, in one go")
    func aVerdictGoesEverywhere() async throws {
        let dir = try FileHelpers.makeTemporaryDirectory()
        defer { FileHelpers.cleanup(dir) }
        let testsDir = dir.appendingPathComponent("Tests")
        try FileManager.default.createDirectory(at: testsDir, withIntermediateDirectories: true)
        try FileHelpers.write("@Test func catchesIt() {}", named: "FooTests.swift", in: testsDir)
        let reporter = MockProgressReporter()
        let deps = makeExecutionDeps(
            cacheStorePath: dir.appendingPathComponent("cache.json").path, reporter: reporter,
            testFilePaths: [testsDir.appendingPathComponent("FooTests.swift").path], projectPath: dir.path
        )
        let logs = dir.appendingPathComponent("logs")
        let mutant = makeMutantDescriptor(id: "m7")

        let result = await ResultRecorder(deps: deps, keepLogsPath: logs.path).record(
            mutant, status: .killed(by: "catchesIt"), duration: 2, output: "the test output", activated: true
        )

        #expect(result.killerTestFile == "Tests/FooTests.swift")
        #expect(result.testDuration == 2)
        #expect(result.activated == true)
        #expect(!result.fromCache)
        let log = try String(contentsOf: logs.appendingPathComponent("m7.log"), encoding: .utf8)
        #expect(log.hasSuffix("the test output"))
        #expect(await deps.cacheStore.cachedResult(for: mutant)?.status == .killed(by: "catchesIt"))
        #expect(await deps.counter.completed == 1)
        #expect(await reporter.events.count == 1)
    }

    @Test("Given no log directory, when a verdict is recorded, then nothing is written but it is still cached")
    func noLogDirectoryWritesNoLog() async throws {
        let dir = try FileHelpers.makeTemporaryDirectory()
        defer { FileHelpers.cleanup(dir) }
        let deps = makeExecutionDeps(cacheStorePath: dir.appendingPathComponent("cache.json").path)
        let mutant = makeMutantDescriptor(id: "m0")

        let result = await ResultRecorder(deps: deps, keepLogsPath: nil).record(mutant, status: .unviable)

        #expect(result.status == .unviable)
        #expect(result.killerTestFile == nil)
        #expect(await deps.cacheStore.cachedResult(for: mutant)?.status == .unviable)
    }

    @Test("Given a mutant the cache knows, when its cached verdict is asked, then it comes back counted and reported")
    func aCachedVerdictIsCountedAndReported() async throws {
        let dir = try FileHelpers.makeTemporaryDirectory()
        defer { FileHelpers.cleanup(dir) }
        let reporter = MockProgressReporter()
        let deps = makeExecutionDeps(cacheStorePath: dir.appendingPathComponent("cache.json").path, reporter: reporter)
        let mutant = makeMutantDescriptor(id: "m0")
        await deps.cacheStore.store(
            status: .survived, for: MutantCacheKey.make(for: mutant), killerTestFile: "Tests/ATests.swift",
            activated: true
        )

        let cached = await ResultRecorder(deps: deps, keepLogsPath: nil).cached(mutant)

        #expect(cached?.status == .survived)
        #expect(cached?.fromCache == true)
        #expect(cached?.killerTestFile == "Tests/ATests.swift")
        #expect(cached?.activated == true)
        #expect(await deps.counter.completed == 1)
        #expect(await reporter.events.count == 1)
    }

    @Test("Given a mutant the cache does not know, when its cached verdict is asked, then there is none")
    func anUnknownMutantHasNoCachedVerdict() async {
        let deps = makeExecutionDeps(cacheStorePath: "/nonexistent/cache.json")

        #expect(await ResultRecorder(deps: deps, keepLogsPath: nil).cached(makeMutantDescriptor()) == nil)
        #expect(await deps.counter.completed == 0)
    }
}
