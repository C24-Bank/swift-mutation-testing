import Foundation
import Testing

@testable import SwiftMutationTesting

@Suite("MutantExecutor Coverage")
struct MutantExecutorCoverageTests {
    @Test("Given test execution throws, when execute called, then error propagates after cleanup")
    func testExecutionThrowingTriggersCleanup() async throws {
        let dir = try FileHelpers.makeTemporaryDirectory()
        defer { FileHelpers.cleanup(dir) }

        let sourceFile = dir.appendingPathComponent("Foo.swift")
        try "let x = true".write(to: sourceFile, atomically: true, encoding: .utf8)

        let executor = MutantExecutor(
            configuration: makeRunnerConfiguration(projectPath: dir.path, projectType: .spm),
            launcher: ThrowingDuringTestMock()
        )
        let mutant = makeMutantDescriptor(
            id: "m0",
            filePath: sourceFile.path,
            originalText: "true",
            mutatedText: "false",
            operatorIdentifier: "BooleanLiteralReplacement",
            replacementKind: .booleanLiteral,
            description: "true → false",
            isSchematizable: true,
            mutatedSourceContent: "let x = false",
            sourceContentHash: "test-hash",
            fingerprint: "fingerprint"
        )
        let input = makeRunnerInput(
            projectPath: dir.path,
            projectType: .spm,
            schematizedFiles: [SchematizedFile(originalPath: sourceFile.path, schematizedContent: "let x = false")],
            mutants: [mutant]
        )

        await #expect(throws: Error.self) {
            _ = try await executor.execute(input)
        }
    }

    @Test("Given a run that ends after its first verdict, when it runs again, then only the other mutant is tested")
    func anInterruptedRunContinuesWhereItStopped() async throws {
        let dir = try FileHelpers.makeTemporaryDirectory()
        defer { FileHelpers.cleanup(dir) }

        let sourceFile = dir.appendingPathComponent("Foo.swift")
        try "let x = true\nlet y = true".write(to: sourceFile, atomically: true, encoding: .utf8)
        let mutants = [
            makeMutantDescriptor(
                id: "m0", filePath: sourceFile.path, utf8Offset: 8, originalText: "true", mutatedText: "false",
                operatorIdentifier: "BooleanLiteralReplacement", replacementKind: .booleanLiteral,
                description: "true → false", isSchematizable: true, mutatedSourceContent: nil,
                sourceContentHash: "test-hash", fingerprint: "f0"
            ),
            makeMutantDescriptor(
                id: "m1", filePath: sourceFile.path, utf8Offset: 21, originalText: "true", mutatedText: "false",
                operatorIdentifier: "BooleanLiteralReplacement", replacementKind: .booleanLiteral,
                description: "true → false", isSchematizable: true, mutatedSourceContent: nil,
                sourceContentHash: "test-hash", fingerprint: "f1"
            ),
        ]
        let schematized = SchematizedFile(
            originalPath: sourceFile.path, schematizedContent: "let x = false\nlet y = false"
        )
        let input = makeRunnerInput(
            projectPath: dir.path, projectType: .spm, schematizedFiles: [schematized], mutants: mutants
        )

        let interrupted = MutantExecutor(
            configuration: makeRunnerConfiguration(projectPath: dir.path, projectType: .spm),
            launcher: ThrowingDuringTestMock(throwingOnTestCall: 3)
        )
        await #expect(throws: Error.self) {
            _ = try await interrupted.execute(input)
        }

        let launcher = RecordingProcessLauncher(responses: [(0, "")])
        let resumed = MutantExecutor(
            configuration: makeRunnerConfiguration(projectPath: dir.path, projectType: .spm),
            launcher: launcher
        )
        let results = try await resumed.execute(input)

        let tested = await launcher.requests.compactMap { $0.additionalEnvironment["__SWIFT_MUTATION_TESTING_ACTIVE"] }
            .filter { !$0.isEmpty }
        #expect(tested == ["m1"])
        #expect(results.map(\.descriptor.id) == ["m0", "m1"])
    }

    @Test("Given build error without line numbers, when retry called, then all mutants in file are excluded")
    func buildErrorWithoutLineNumbersExcludesAllMutants() async throws {
        let dir = try FileHelpers.makeTemporaryDirectory()
        defer { FileHelpers.cleanup(dir) }

        let fooFile = dir.appendingPathComponent("Foo.swift")
        try "let x = true".write(to: fooFile, atomically: true, encoding: .utf8)

        let executor = MutantExecutor(
            configuration: makeRunnerConfiguration(projectPath: dir.path, projectType: .spm),
            launcher: SPMErrorWithoutLineNumberMock()
        )
        let mutant = makeMutantDescriptor(
            id: "m0",
            filePath: fooFile.path,
            originalText: "true",
            mutatedText: "false",
            operatorIdentifier: "BooleanLiteralReplacement",
            replacementKind: .booleanLiteral,
            description: "true → false",
            isSchematizable: true,
            mutatedSourceContent: "let x = false",
            sourceContentHash: "test-hash",
            fingerprint: "fingerprint"
        )
        let input = makeRunnerInput(
            projectPath: dir.path,
            projectType: .spm,
            schematizedFiles: [SchematizedFile(originalPath: fooFile.path, schematizedContent: "let x = false")],
            mutants: [mutant]
        )

        let results = try await executor.execute(input)

        #expect(results.count == 1)
    }

    @Test("Given single case before default in schema, when that case excluded, then default line is preserved")
    func singleCaseExclusionPreservesDefault() async throws {
        let dir = try FileHelpers.makeTemporaryDirectory()
        defer { FileHelpers.cleanup(dir) }

        let fooFile = dir.appendingPathComponent("Foo.swift")
        try "let original = true".write(to: fooFile, atomically: true, encoding: .utf8)

        let schematized =
            "func foo() {\n"
            + "switch __swiftMutationTestingID {\n"
            + "case \"swift-mutation-testing_0\":\n"
            + "return true\n"
            + "default:\n"
            + "return nil\n"
            + "}\n"
            + "}"

        let executor = MutantExecutor(
            configuration: makeRunnerConfiguration(projectPath: dir.path, projectType: .spm),
            launcher: SPMSingleCaseExclusionMock()
        )
        let mutant = makeMutantDescriptor(
            id: "swift-mutation-testing_0",
            filePath: fooFile.path,
            originalText: "true",
            mutatedText: "false",
            operatorIdentifier: "BooleanLiteralReplacement",
            replacementKind: .booleanLiteral,
            description: "true → false",
            isSchematizable: true,
            mutatedSourceContent: "let x = false",
            sourceContentHash: "test-hash",
            fingerprint: "fingerprint"
        )
        let input = makeRunnerInput(
            projectPath: dir.path,
            projectType: .spm,
            schematizedFiles: [
                SchematizedFile(originalPath: fooFile.path, schematizedContent: schematized)
            ],
            mutants: [mutant]
        )

        let results = try await executor.execute(input)

        #expect(results.count == 1)
    }
}
