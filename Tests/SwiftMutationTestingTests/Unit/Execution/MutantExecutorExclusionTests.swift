import Foundation
import Testing

@testable import SwiftMutationTesting

@Suite("MutantExecutor — excluding the mutants of a failing file")
struct MutantExecutorExclusionTests {
    @Test("Given the sandbox copy is gone, when its mutants are excluded, then all go and the original is restored")
    func aMissingSandboxCopyExcludesEveryMutantAndRestoresTheOriginal() throws {
        let dir = try FileHelpers.makeTemporaryDirectory()
        defer { FileHelpers.cleanup(dir) }
        let original = dir.appendingPathComponent("Foo.swift")
        let sandboxCopy = dir.appendingPathComponent("sandbox/Foo.swift")
        try FileManager.default.createDirectory(
            at: sandboxCopy.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        try "let x = true".write(to: original, atomically: true, encoding: .utf8)
        let mutants = [
            makeMutantDescriptor(id: "swift-mutation-testing_0", filePath: original.path, isSchematizable: true)
        ]

        let excluded = MutantExecutor(
            configuration: makeRunnerConfiguration(projectPath: dir.path, projectType: .spm),
            launcher: MockProcessLauncher(exitCode: 0)
        ).excludeProblematicMutants(
            sandboxPath: sandboxCopy.path,
            originalPath: original.path,
            errorOutput: "\(sandboxCopy.path):1:5: error: cannot find 'y' in scope",
            mutantsInFile: mutants,
            importStyle: .implicit
        )

        #expect(excluded.map(\.id) == ["swift-mutation-testing_0"])
        #expect(try String(contentsOf: sandboxCopy, encoding: .utf8) == "let x = true")
    }
}
