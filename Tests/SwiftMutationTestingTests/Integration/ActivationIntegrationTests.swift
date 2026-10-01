import Foundation
import Testing

@testable import SwiftMutationTesting

@Suite(.tags(.integration))
struct ActivationIntegrationTests {

    @Test("Given a file no test reaches, when executed, then its mutants have no coverage and the rest are unchanged")
    func untestedCodeIsReportedAsNoCoverage() async throws {
        let fixtureURL = calcLibraryURL()
        let configuration = makeRunnerConfiguration(
            projectPath: fixtureURL.path, projectType: .spm, timeout: 60, buildTimeout: 120, noCache: true
        )
        let input = try await DiscoveryPipeline().run(
            input: DiscoveryInput(
                projectPath: fixtureURL.path, projectType: .spm, timeout: 60, concurrency: 1, noCache: true,
                sourcesPath: fixtureURL.path, excludePatterns: [], operators: []
            )
        )

        let results = try await MutantExecutor(configuration: configuration, launcher: SPMProcessLauncher())
            .execute(input)

        let byFile = Dictionary(grouping: results) { URL(fileURLWithPath: $0.descriptor.filePath).lastPathComponent }
        let summary = RunnerSummary(results: results, totalDuration: 0)

        #expect(byFile["Logic.swift"]?.map(\.status) == [.noCoverage, .noCoverage])
        #expect(byFile["Logic.swift"]?.map(\.activated) == [false, false])
        #expect(summary.killed.count == 7)
        #expect(summary.survived.count == 2)
        #expect(summary.noCoverage.count == 2)
        #expect(summary.killed.allSatisfy { $0.activated == true })
        #expect(summary.survived.allSatisfy { $0.activated == true })
        #expect(summary.integrityWarnings.isEmpty)
        #expect(summary.activationNotMeasured.isEmpty)
    }
}

private func calcLibraryURL() -> URL {
    URL(filePath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appending(path: "Fixtures/CalcLibrary")
}
