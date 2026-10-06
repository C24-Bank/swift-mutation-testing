import Foundation
import Testing

@testable import SwiftMutationTesting

@Suite("MutantExecutor — cache and test selection")
struct MutantExecutorCacheSelectionTests {
    @Test("Given every mutant cached against the same tests, when executed, then the verdicts come from the cache")
    func theSameTargetReusesTheCache() async throws {
        let output = try await runWithCache(madeFor: "UnitTests", runningAgainst: "UnitTests")

        #expect(output.contains("Loaded 2 mutants from cache"))
    }

    @Test("Given every mutant cached against another target, when executed, then none is taken from the cache")
    func anotherTargetTestsEveryMutantAgain() async throws {
        let output = try await runWithCache(madeFor: "UnitTests", runningAgainst: "EndToEndTests")

        #expect(!output.contains("from cache"))
    }

    // MARK: - Helpers

    private func runWithCache(madeFor cachedTarget: String, runningAgainst target: String) async throws -> String {
        let dir = try FileHelpers.makeTemporaryDirectory()
        defer { FileHelpers.cleanup(dir) }

        let mutants = ["let x = false", "let y = false"].enumerated().map { index, content in
            makeMutantDescriptor(
                id: "m\(index)", originalText: "true", mutatedText: "false",
                operatorIdentifier: "BooleanLiteralReplacement", replacementKind: .booleanLiteral,
                isSchematizable: true, mutatedSourceContent: content, sourceContentHash: "hash-\(index)"
            )
        }

        let cacheDir = dir.appendingPathComponent(CacheStore.directoryName)
        try FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
        let cacheStore = CacheStore(storePath: cacheDir.appendingPathComponent("results.json").path)
        for mutant in mutants {
            await cacheStore.store(status: .killed(by: "T"), for: MutantCacheKey.make(for: mutant))
        }
        try await cacheStore.persist()
        try await cacheStore.persistMetadata(
            CacheStore.CacheMetadata(
                testFileHashes: [:],
                testSelection: CacheTestSelection(
                    makeRunnerConfiguration(projectPath: dir.path, testTarget: cachedTarget).build
                )
            )
        )

        let executor = MutantExecutor(
            configuration: makeRunnerConfiguration(projectPath: dir.path, testTarget: target, quiet: false),
            launcher: MockProcessLauncher(exitCode: 1)
        )
        let input = makeRunnerInput(projectPath: dir.path, mutants: mutants)

        return await captureOutput {
            _ = try? await executor.execute(input)
        }
    }
}
