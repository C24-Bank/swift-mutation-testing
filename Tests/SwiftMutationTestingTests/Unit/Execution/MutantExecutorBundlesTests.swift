import Foundation
import Testing

@testable import SwiftMutationTesting

@Suite("MutantExecutor — test bundles")
struct MutantExecutorBundlesTests {

    @Test("Given two bundles and a mutant only the second kills, when executed, then it is killed")
    func theSecondBundleKillsTheMutant() async throws {
        let dir = try FileHelpers.makeTemporaryDirectory()
        defer { FileHelpers.cleanup(dir) }
        let sourceFile = try project(in: dir, suiteAt: nil)
        let launcher = TwoBundleLauncher(killers: ["CoreBTests": "even()"])

        let results = try await execute(in: dir, sourceFile: sourceFile, launcher: launcher)

        #expect(results.map(\.status) == [.killed(by: "even()")])
        #expect(
            await launcher.runs == [
                .init(bundle: "CoreATests", filter: nil, mutantID: "m0"),
                .init(bundle: "CoreBTests", filter: nil, mutantID: "m0"),
            ]
        )
    }

    @Test("Given a suite declared in one test target, when the targeted run kills, then only that bundle ran")
    func theTargetedRunGoesToTheSuitesOwnBundle() async throws {
        let dir = try FileHelpers.makeTemporaryDirectory()
        defer { FileHelpers.cleanup(dir) }
        let sourceFile = try project(in: dir, suiteAt: "Tests/CoreATests/AdderTests.swift")
        let launcher = TwoBundleLauncher(killers: ["CoreATests": "positive()"])

        let results = try await execute(in: dir, sourceFile: sourceFile, launcher: launcher)

        #expect(results.map(\.status) == [.killed(by: "positive()")])
        #expect(await launcher.runs == [.init(bundle: "CoreATests", filter: "AdderTests", mutantID: "m0")])
    }

    @Test("Given a suite whose test target cannot be told, when targeted, then every bundle gets the filter")
    func anUnplaceableSuiteIsTriedInEveryBundle() async throws {
        let dir = try FileHelpers.makeTemporaryDirectory()
        defer { FileHelpers.cleanup(dir) }
        let sourceFile = try project(in: dir, suiteAt: "Tests/AdderTests.swift")
        let launcher = TwoBundleLauncher(killers: ["CoreBTests": "even()"])

        let results = try await execute(in: dir, sourceFile: sourceFile, launcher: launcher)

        #expect(results.map(\.status) == [.killed(by: "even()")])
        #expect(
            await launcher.runs == [
                .init(bundle: "CoreATests", filter: "AdderTests", mutantID: "m0"),
                .init(bundle: "CoreBTests", filter: "AdderTests", mutantID: "m0"),
            ]
        )
    }

    @Test("Given a bundle that reports no tests, when probed, then no mutant is run against it")
    func aBundleWithoutTestsIsDropped() async throws {
        let dir = try FileHelpers.makeTemporaryDirectory()
        defer { FileHelpers.cleanup(dir) }
        let sourceFile = try project(in: dir, suiteAt: nil)
        let launcher = TwoBundleLauncher(noTestsIn: ["CoreBTests"])

        let results = try await execute(in: dir, sourceFile: sourceFile, launcher: launcher)

        #expect(results.map(\.status) == [.survived])
        #expect(await launcher.runs == [.init(bundle: "CoreATests", filter: nil, mutantID: "m0")])
    }

    @Test("Given the second bundle fails without a mutant, when probed, then the run stops on the baseline")
    func aFailingBaselineInTheSecondBundleStopsTheRun() async throws {
        let dir = try FileHelpers.makeTemporaryDirectory()
        defer { FileHelpers.cleanup(dir) }
        let sourceFile = try project(in: dir, suiteAt: nil)
        let launcher = TwoBundleLauncher(baselineFailsIn: ["CoreBTests"])

        await #expect(throws: BaselineError.self) {
            try await execute(in: dir, sourceFile: sourceFile, launcher: launcher)
        }
        #expect(await launcher.runs.isEmpty)
    }

    // MARK: - Helpers

    private func project(in dir: URL, suiteAt suitePath: String?) throws -> URL {
        let sourceFile = dir.appendingPathComponent("Sources/CoreA/Adder.swift")
        try FileManager.default.createDirectory(
            at: sourceFile.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        try "let x = true".write(to: sourceFile, atomically: true, encoding: .utf8)

        if let suitePath {
            let suiteFile = dir.appendingPathComponent(suitePath)
            try FileManager.default.createDirectory(
                at: suiteFile.deletingLastPathComponent(), withIntermediateDirectories: true
            )
            try "@Suite struct AdderTests {}".write(to: suiteFile, atomically: true, encoding: .utf8)
        }

        return sourceFile
    }

    private func execute(in dir: URL, sourceFile: URL, launcher: TwoBundleLauncher) async throws -> [ExecutionResult] {
        try await MutantExecutor(
            configuration: makeRunnerConfiguration(projectPath: dir.path, projectType: .spm),
            launcher: launcher
        ).execute(
            makeRunnerInput(
                projectPath: dir.path,
                projectType: .spm,
                schematizedFiles: [SchematizedFile(originalPath: sourceFile.path, schematizedContent: "let x = false")],
                mutants: [makeMutantDescriptor(id: "m0", filePath: sourceFile.path, isSchematizable: true)]
            )
        )
    }
}
