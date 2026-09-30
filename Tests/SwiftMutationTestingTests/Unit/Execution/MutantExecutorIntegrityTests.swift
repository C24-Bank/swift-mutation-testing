import Foundation
import Testing

@testable import SwiftMutationTesting

@Suite("MutantExecutor — integrity")
struct MutantExecutorIntegrityTests {

    @Test("Given a schema identical to its original, when executed, then the run stops before any process runs")
    func anUnappliedSchemaStopsTheRunBeforeTheBuild() async throws {
        let dir = try FileHelpers.makeTemporaryDirectory()
        defer { FileHelpers.cleanup(dir) }
        let sourceFile = dir.appendingPathComponent("Foo.swift")
        try "let x = true".write(to: sourceFile, atomically: true, encoding: .utf8)
        let launcher = RecordingProcessLauncher(responses: [(0, "")])
        let executor = MutantExecutor(
            configuration: makeRunnerConfiguration(projectPath: dir.path, projectType: .spm), launcher: launcher
        )
        let input = RunnerInput(
            projectPath: dir.path, projectType: .spm, timeout: 60, concurrency: 1, noCache: true,
            schematizedFiles: [SchematizedFile(originalPath: sourceFile.path, schematizedContent: "let x = true")],
            mutants: [makeMutantDescriptor(id: "m0", filePath: sourceFile.path, isSchematizable: true)]
        )

        let sandboxesBefore = try? FileManager.default.contentsOfDirectory(atPath: SandboxName.directory.path)

        await #expect(throws: IntegrityError.schemaNotApplied(path: sourceFile.path)) {
            try await executor.execute(input)
        }
        let sandboxesAfter = try? FileManager.default.contentsOfDirectory(atPath: SandboxName.directory.path)
        #expect(await launcher.requests.isEmpty)
        #expect(sandboxesAfter == sandboxesBefore)
    }
}
