import Foundation
import Testing

@testable import SwiftMutationTesting

@Suite("CI run support")
struct CIRunTests {
    @Test("Given the CI flags, when parsed, then cache path, in-place, plan, cleanup and summary are set")
    func parsesCIFlags() throws {
        let result = try CommandLineParser().parse([
            "run", "--scheme", "App", "--destination", "d",
            "--cache-path", "/ci/cache", "--in-place", "--test-plan", "C24Unit",
            "--cleanup-simulators", "--summary-output", "summary.md",
        ])

        #expect(result.build.cachePath == "/ci/cache")
        #expect(result.build.inPlace)
        #expect(result.build.testPlan == "C24Unit")
        #expect(result.build.cleanupSimulators)
        #expect(result.reporting.summaryOutput == "summary.md")
    }

    @Test("Given results stored after the save interval, when the cache is reloaded, then they survive an interruption")
    func resultsAreSavedDuringTheRun() async throws {
        let dir = try FileHelpers.makeTemporaryDirectory()
        defer { FileHelpers.cleanup(dir) }
        let path = dir.appendingPathComponent("results.json").path

        let store = CacheStore(storePath: path)
        await store.setPersistInterval(0)
        await store.store(status: .survived, for: makeMutantCacheKey(utf8Offset: 1))

        let reloaded = CacheStore(storePath: path)
        try await reloaded.load()

        #expect(await reloaded.result(for: makeMutantCacheKey(utf8Offset: 1)) == .survived)
    }

    @Test("Given an in-place sandbox, when the run is interrupted, then its original files are written back")
    func interruptedInPlaceRunRestoresOriginals() throws {
        let dir = try FileHelpers.makeTemporaryDirectory()
        defer { FileHelpers.cleanup(dir) }
        let file = dir.appendingPathComponent("Foo.swift")
        try "let mutated = true".write(to: file, atomically: true, encoding: .utf8)

        let registry = SandboxRegistry()
        registry.register(
            Sandbox(
                rootURL: dir,
                originals: [Sandbox.OriginalFile(url: file, content: Data("let original = true".utf8))],
                isInPlace: true
            )
        )
        registry.cleanup()

        #expect(try String(contentsOf: file, encoding: .utf8) == "let original = true")
    }

    @Test("Given simulators from simctl, when leftover clones are looked up, then only XMR- clones are returned")
    func findsOnlyLeftoverClones() {
        let json = """
            {"devices":{"iOS":[
              {"udid":"A","name":"XMR-1234-0","state":"Booted"},
              {"udid":"B","name":"MUTATION-1 Tests","state":"Shutdown"},
              {"udid":"C","name":"XMR-1234-1","state":"Shutdown"}
            ]}}
            """

        #expect(SimulatorManager.leftoverCloneUDIDs(in: json).sorted() == ["A", "C"])
    }

    @Test("Given untested files and survivors, when the summary is rendered, then it lists both with their spots")
    func summaryListsEasyWins() {
        let results = [
            makeExecutionResult(id: "1", filePath: "/p/A.swift", line: 3, status: .survived),
            makeExecutionResult(id: "2", filePath: "/p/A.swift", line: 9, status: .killed(by: "t")),
            makeExecutionResult(id: "3", filePath: "/p/Untested.swift", status: .noCoverage),
            makeExecutionResult(id: "4", filePath: "/p/Untested.swift", status: .noCoverage),
        ]

        let markdown = SummaryReporter(outputPath: "", projectRoot: "/p")
            .render(RunnerSummary(results: results, totalDuration: 7200))

        #expect(markdown.contains("| 4 | 1 | 1 | 2 | 0 | 0 | 25.0% | 2.0 h |"))
        #expect(markdown.contains("## Files without any tests (1 files)"))
        #expect(markdown.contains("| `Untested.swift` | 2 |"))
        #expect(markdown.contains("| `A.swift` | 1 | 50.0% | 3: + → - |"))
        #expect(markdown.contains("| ArithmeticOperatorReplacement | a calculation is not pinned | 4 | 1 | 25.0% |"))

    }

    @Test("Given a type whose explanation contains pipes, when the summary is rendered, then they are escaped for the table")
    func summaryEscapesPipesInExplanations() {
        let logical = ExecutionResult(
            descriptor: makeMutantDescriptor(filePath: "/p/B.swift", operatorIdentifier: "LogicalOperatorReplacement"),
            status: .survived,
            testDuration: 0
        )

        let markdown = SummaryReporter(outputPath: "", projectRoot: "/p")
            .render(RunnerSummary(results: [logical], totalDuration: 0))

        #expect(markdown.contains("| LogicalOperatorReplacement | `&&` and `\\|\\|` are interchangeable |"))
    }
}
