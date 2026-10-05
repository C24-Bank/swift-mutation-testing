import Foundation
import Testing

@testable import SwiftMutationTesting

@Suite(.tags(.integration), .serialized, .notInsideAMutationRun)
struct MutantExecutorSPMIntegrationTests {

    @Test("Given SPM fixture with partial coverage, when executed, then killed and survived mutants match expected")
    func spmFixtureResultsMatchExpected() async throws {
        let fixture = try FixtureCopy.make("CalcLibrary")
        defer { fixture.remove() }
        let fixtureURL = fixture.url
        let configuration = makeConfiguration(fixtureURL: fixtureURL)
        let input = makeInput(fixtureURL: fixtureURL)

        let results = try await MutantExecutor(
            configuration: configuration,
            launcher: SPMProcessLauncher()
        ).execute(input)

        let killed = results.filter {
            if case .killed = $0.status { return true }
            return false
        }
        let survived = results.filter { $0.status == .survived }
        let killedIDs = Set(killed.map { $0.descriptor.id })

        #expect(killed.count == 3)
        #expect(survived.count == 3)
        #expect(killedIDs == Set(["m1", "m2", "m4"]))
    }

    @Test("Given SPM fixture, when executed, then original source files are not modified")
    func spmFixtureSourceFilesNotModified() async throws {
        let fixture = try FixtureCopy.make("CalcLibrary")
        defer { fixture.remove() }
        let fixtureURL = fixture.url
        let calculatorURL = fixtureURL.appending(path: "Sources/CalcLibrary/Calculator.swift")

        let before = try String(contentsOf: calculatorURL, encoding: .utf8)

        let configuration = makeConfiguration(fixtureURL: fixtureURL)
        let input = makeInput(fixtureURL: fixtureURL)
        _ = try await MutantExecutor(
            configuration: configuration,
            launcher: SPMProcessLauncher()
        ).execute(input)

        let after = try String(contentsOf: calculatorURL, encoding: .utf8)

        #expect(before == after)
    }
}

private func makeConfiguration(fixtureURL: URL) -> RunnerConfiguration {
    RunnerConfiguration(
        projectPath: fixtureURL.path,
        build: .init(projectType: .spm, timeout: 60.0, buildTimeout: 60.0, concurrency: 1, noCache: true),
        reporting: .init(quiet: true),
        filter: .init(excludePatterns: [], operators: [])
    )
}

private func makeInput(fixtureURL: URL) -> RunnerInput {
    RunnerInput(
        projectPath: fixtureURL.path,
        projectType: .spm,
        timeout: 60.0,
        concurrency: 1,
        noCache: true,
        schematizedFiles: applied(
            makeSchematizedFiles(fixtureURL: fixtureURL), for: makeMutants(fixtureURL: fixtureURL)
        ),
        mutants: makeMutants(fixtureURL: fixtureURL)
    )
}

private func makeSchematizedFiles(fixtureURL: URL) -> [SchematizedFile] {
    let calculatorPath = fixtureURL.appending(path: "Sources/CalcLibrary/Calculator.swift").path
    let validatorPath = fixtureURL.appending(path: "Sources/CalcLibrary/Validator.swift").path

    let (calculatorID, calculatorActivation) = (
        SupportDeclarations.identifier(for: calculatorPath), SupportDeclarations.activationCall(for: calculatorPath)
    )
    let (validatorID, validatorActivation) = (
        SupportDeclarations.identifier(for: validatorPath), SupportDeclarations.activationCall(for: validatorPath)
    )

    return [
        SchematizedFile(
            originalPath: calculatorPath,
            schematizedContent: """
                struct Calculator {
                    func add(_ a: Int, _ b: Int) -> Int {
                        (\(calculatorID) == "m1") ? (\(calculatorActivation), a - b).1 : a + b
                    }
                    func subtract(_ a: Int, _ b: Int) -> Int {
                        (\(calculatorID) == "m2") ? (\(calculatorActivation), a + b).1 : a - b
                    }
                    func isPositive(_ n: Int) -> Bool {
                        (\(calculatorID) == "m3") ? (\(calculatorActivation), n >= 0).1 : n > 0
                    }
                }
                """
        ),
        SchematizedFile(
            originalPath: validatorPath,
            schematizedContent: """
                struct Validator {
                    func isInRange(_ value: Int) -> Bool {
                        ((\(validatorID) == "m4")
                            ? (\(validatorActivation), value > 0).1 : value >= 0)
                            && ((\(validatorID) == "m5")
                                ? (\(validatorActivation), value < 100).1 : value <= 100)
                    }
                }
                """
        ),
    ]
}

private func makeMutants(fixtureURL: URL) -> [MutantDescriptor] {
    let calculatorPath = fixtureURL.appending(path: "Sources/CalcLibrary/Calculator.swift").path
    let validatorPath = fixtureURL.appending(path: "Sources/CalcLibrary/Validator.swift").path
    let logicPath = fixtureURL.appending(path: "Sources/CalcLibrary/Logic.swift").path

    return calculatorMutants(path: calculatorPath)
        + validatorMutants(path: validatorPath)
        + incompatibleMutants(path: logicPath)
}

private func calculatorMutants(path: String) -> [MutantDescriptor] {
    [
        MutantDescriptor(
            id: "m1", filePath: path,
            line: 2, column: 44, utf8Offset: 64,
            originalText: "+", mutatedText: "-",
            operatorIdentifier: "binaryOperator", replacementKind: .binaryOperator,
            description: "Replace + with -", isSchematizable: true, mutatedSourceContent: nil,
            sourceContentHash: "test-hash",
            fingerprint: "fingerprint"
        ),
        MutantDescriptor(
            id: "m2", filePath: path,
            line: 3, column: 47, utf8Offset: 119,
            originalText: "-", mutatedText: "+",
            operatorIdentifier: "binaryOperator", replacementKind: .binaryOperator,
            description: "Replace - with +", isSchematizable: true, mutatedSourceContent: nil,
            sourceContentHash: "test-hash",
            fingerprint: "fingerprint"
        ),
        MutantDescriptor(
            id: "m3", filePath: path,
            line: 4, column: 40, utf8Offset: 167,
            originalText: ">", mutatedText: ">=",
            operatorIdentifier: "binaryOperator", replacementKind: .binaryOperator,
            description: "Replace > with >=", isSchematizable: true, mutatedSourceContent: nil,
            sourceContentHash: "test-hash",
            fingerprint: "fingerprint"
        ),
    ]
}

private func validatorMutants(path: String) -> [MutantDescriptor] {
    [
        MutantDescriptor(
            id: "m4", filePath: path,
            line: 2, column: 49, utf8Offset: 68,
            originalText: ">=", mutatedText: ">",
            operatorIdentifier: "binaryOperator", replacementKind: .binaryOperator,
            description: "Replace >= with >", isSchematizable: true, mutatedSourceContent: nil,
            sourceContentHash: "test-hash",
            fingerprint: "fingerprint"
        ),
        MutantDescriptor(
            id: "m5", filePath: path,
            line: 2, column: 62, utf8Offset: 81,
            originalText: "<=", mutatedText: "<",
            operatorIdentifier: "binaryOperator", replacementKind: .binaryOperator,
            description: "Replace <= with <", isSchematizable: true, mutatedSourceContent: nil,
            sourceContentHash: "test-hash",
            fingerprint: "fingerprint"
        ),
    ]
}

private func incompatibleMutants(path: String) -> [MutantDescriptor] {
    [
        MutantDescriptor(
            id: "mi1", filePath: path,
            line: 2, column: 45, utf8Offset: 59,
            originalText: ">=", mutatedText: ">",
            operatorIdentifier: "binaryOperator", replacementKind: .binaryOperator,
            description: "Replace >= with >",
            isSchematizable: false,
            mutatedSourceContent: """
                struct Logic {
                    func isNonNegative(_ n: Int) -> Bool { n > 0 }
                }
                """,
            sourceContentHash: "test-hash",
            fingerprint: "fingerprint"
        )
    ]
}
