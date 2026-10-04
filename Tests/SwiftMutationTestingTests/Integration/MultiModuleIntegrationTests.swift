import Foundation
import Testing

@testable import SwiftMutationTesting

@Suite(.tags(.integration), .serialized)
struct MultiModuleIntegrationTests {

    @Test("Given a package with two modules, when executed, then one build tests every mutant of both")
    func bothModulesAreSchematizedInOneBuild() async throws {
        let fixture = try FixtureCopy.make("CalcModules")
        defer { fixture.remove() }
        let fixtureURL = fixture.url
        let configuration = makeRunnerConfiguration(
            projectPath: fixtureURL.path, projectType: .spm, timeout: 60, buildTimeout: 120, noCache: true
        )
        let input = try await DiscoveryPipeline().run(
            input: DiscoveryInput(
                projectPath: fixtureURL.path, projectType: .spm, timeout: 60, concurrency: 1, noCache: true,
                sourcesPath: fixtureURL.path, excludePatterns: [], operators: []
            )
        )
        let launcher = CountingLauncher(wrapping: SPMProcessLauncher())

        let results = try await MutantExecutor(configuration: configuration, launcher: launcher).execute(input)

        let files = Set(results.map { URL(fileURLWithPath: $0.descriptor.filePath).lastPathComponent })
        #expect(files == ["Adder.swift", "Multiplier.swift"])
        #expect(results.count == 6)
        #expect(results.allSatisfy { if case .killed = $0.status { return true } else { return false } })
        #expect(await launcher.buildCount == 1)
    }
}
