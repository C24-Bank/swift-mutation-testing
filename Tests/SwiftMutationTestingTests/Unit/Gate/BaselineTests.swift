import Foundation
import Testing

@testable import SwiftMutationTesting

@Suite("Baseline")
struct BaselineTests {
    @Test("Given a summary, when a baseline is made, then it records only the undetected mutants")
    func recordsOnlyUndetectedMutants() {
        let summary = RunnerSummary(
            results: [
                makeExecutionResult(filePath: "/p/Sources/A.swift", line: 4, status: .survived, fingerprint: "s"),
                makeExecutionResult(filePath: "/p/Sources/A.swift", line: 2, status: .noCoverage, fingerprint: "n"),
                makeExecutionResult(status: .killed(by: "t"), fingerprint: "k"),
                makeExecutionResult(status: .timeout, fingerprint: "t"),
                makeExecutionResult(status: .unviable, fingerprint: "u"),
            ],
            totalDuration: 0
        )

        let baseline = Baseline(
            summary: summary, scope: scope(), projectPath: "/p", toolVersion: "1.6.0", createdAt: Date()
        )

        #expect(baseline.undetected.map(\.fingerprint) == ["n", "s"])
        #expect(baseline.undetected.map(\.status) == ["noCoverage", "survived"])
        #expect(baseline.undetected.map(\.file) == ["Sources/A.swift", "Sources/A.swift"])
        #expect(baseline.score == summary.score)
        #expect(baseline.formatVersion == Baseline.formatVersion)
    }

    @Test("Given entries in any order, when a baseline is made, then they are sorted by file, line and fingerprint")
    func sortsEntries() {
        let entries = [("B.swift", 1, "z"), ("A.swift", 7, "y"), ("A.swift", 7, "x"), ("A.swift", 3, "w")].map {
            BaselineEntry(
                fingerprint: $0.2, file: $0.0, line: $0.1, operatorIdentifier: "op", original: "<",
                replacement: "<=", status: "survived"
            )
        }

        let baseline = Baseline(toolVersion: "1", createdAt: Date(), score: 0, scope: scope(), undetected: entries)

        #expect(baseline.undetected.map(\.fingerprint) == ["w", "x", "y", "z"])
    }

    @Test("Given operators and patterns in any order, when a scope is made, then both lists are sorted")
    func scopeSortsItsLists() {
        let scope = BaselineScope(operators: ["b", "a"], sourcesPath: ".", excludePatterns: ["/Z/", "/A/"])

        #expect(scope.operators == ["a", "b"])
        #expect(scope.excludePatterns == ["/A/", "/Z/"])
    }

    @Test("Given no operator filter and no sources path, when a scope is read, then it is every operator at the root")
    func scopeOfADefaultConfiguration() {
        let scope = BaselineScope(configuration: makeRunnerConfiguration(projectPath: "/tmp"))

        #expect(scope.operators == DiscoveryPipeline.allOperatorNames.sorted())
        #expect(scope.sourcesPath == ".")
        #expect(scope.excludePatterns.isEmpty)
    }

    @Test("Given a sources path inside the project, when a scope is read, then it is relative to the project")
    func scopeSourcesPathIsProjectRelative() throws {
        let dir = try FileHelpers.makeTemporaryDirectory()
        defer { FileHelpers.cleanup(dir) }
        let sources = dir.appendingPathComponent("Sources/App")
        try FileManager.default.createDirectory(at: sources, withIntermediateDirectories: true)

        let base = makeRunnerConfiguration(projectPath: dir.path)
        let configuration = RunnerConfiguration(
            projectPath: base.projectPath,
            build: base.build,
            reporting: base.reporting,
            filter: .init(sourcesPath: sources.path, excludePatterns: ["/Generated/"], operators: ["NegateConditional"])
        )

        let scope = BaselineScope(configuration: configuration)

        #expect(scope.sourcesPath == "Sources/App")
        #expect(scope.operators == ["NegateConditional"])
        #expect(scope.excludePatterns == ["/Generated/"])
    }

    @Test("Given two equal scopes, when compared, then there is no difference")
    func equalScopesHaveNoDifferences() {
        #expect(scope().differences(from: scope()).isEmpty)
    }

    @Test("Given scopes that differ in every field, when compared, then each difference is named")
    func namesEachDifference() {
        let recorded = BaselineScope(operators: ["A", "B"], sourcesPath: ".", excludePatterns: [])
        let current = BaselineScope(operators: ["A"], sourcesPath: "Sources", excludePatterns: ["/Gen/"])

        let differences = current.differences(from: recorded)

        #expect(
            differences == [
                "operators: A, B → A",
                "sources path: . → Sources",
                "exclude patterns: none → /Gen/",
            ]
        )
    }

    @Test("Given an entry, when encoded, then its operator is written under the key operator")
    func entryEncodesTheOperatorKey() throws {
        let entry = BaselineEntry(
            fingerprint: "f", file: "A.swift", line: 1, operatorIdentifier: "SwapTernary", original: "a",
            replacement: "b", status: "survived"
        )

        let json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(entry)) as? [String: Any]

        #expect(json?["operator"] as? String == "SwapTernary")
        #expect(json?["operatorIdentifier"] == nil)
    }

    private func scope() -> BaselineScope {
        BaselineScope(operators: DiscoveryPipeline.allOperatorNames, sourcesPath: ".", excludePatterns: [])
    }
}
