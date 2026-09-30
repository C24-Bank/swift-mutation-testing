import Foundation
import Testing

@testable import SwiftMutationTesting

@Suite("Stryker score parity")
struct StrykerScoreParityTests {
    @Test("Given every status across two files, when the JSON is scored by Stryker's rules, then it matches ours")
    func overallScoreMatchesStryker() throws {
        let summary = mixedSummary()

        let mutants = try reportedMutants(summary).values.flatMap { $0 }

        #expect(try strykerScore(mutants) == summary.score)
    }

    @Test("Given every status across two files, when each file is scored by Stryker's rules, then it matches ours")
    func perFileScoreMatchesStryker() throws {
        let summary = mixedSummary()

        let reported = try reportedMutants(summary)

        for (filePath, results) in summary.resultsByFile {
            let file = RunnerSummary(results: results, totalDuration: 0)
            let key = String(filePath.dropFirst(projectRoot.count))
            let mutants = try #require(reported[key])
            #expect(try strykerScore(mutants) == file.score)
        }
    }

    @Test("Given every status, when reported, then each one is a status value the Stryker schema defines")
    func everyStatusIsInTheSchema() throws {
        let schemaStatuses: Set<String> = [
            "Killed", "Survived", "NoCoverage", "CompileError", "RuntimeError", "Timeout", "Ignored", "Pending",
        ]

        let statuses = try reportedMutants(mixedSummary()).values.flatMap { $0 }.compactMap { $0["status"] as? String }

        #expect(statuses.count == mixedSummary().results.count)
        #expect(Set(statuses).isSubset(of: schemaStatuses))
    }

    private let projectRoot = "/abs/MyApp"

    private func mixedSummary() -> RunnerSummary {
        let calc = "/abs/MyApp/Sources/Calc.swift"
        let parser = "/abs/MyApp/Sources/Parser.swift"
        return RunnerSummary(
            results: [
                makeExecutionResult(id: "1", filePath: calc, line: 1, status: .killed(by: "CalcTests.testAdd")),
                makeExecutionResult(id: "2", filePath: calc, line: 2, status: .killedByCrash),
                makeExecutionResult(id: "3", filePath: calc, line: 3, status: .timeout),
                makeExecutionResult(id: "4", filePath: calc, line: 4, status: .survived),
                makeExecutionResult(id: "5", filePath: calc, line: 5, status: .unviable),
                makeExecutionResult(id: "6", filePath: parser, line: 1, status: .timeout),
                makeExecutionResult(id: "7", filePath: parser, line: 2, status: .noCoverage),
                makeExecutionResult(id: "8", filePath: parser, line: 3, status: .survived),
                makeExecutionResult(id: "9", filePath: parser, line: 4, status: .killedByCrash),
                makeExecutionResult(id: "10", filePath: parser, line: 5, status: .unviable),
            ],
            totalDuration: 0
        )
    }

    private func reportedMutants(_ summary: RunnerSummary) throws -> [String: [[String: Any]]] {
        let dir = try FileHelpers.makeTemporaryDirectory()
        defer { FileHelpers.cleanup(dir) }

        let outputPath = dir.appendingPathComponent("mutation.json").path
        try JsonReporter(outputPath: outputPath, projectRoot: projectRoot).report(summary)

        let data = try Data(contentsOf: URL(fileURLWithPath: outputPath))
        let json = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let files = try #require(json["files"] as? [String: [String: Any]])
        return try files.mapValues { try #require($0["mutants"] as? [[String: Any]]) }
    }

    private func strykerScore(_ mutants: [[String: Any]]) throws -> Double {
        let statuses = mutants.compactMap { $0["status"] as? String }
        let detected = statuses.filter { $0 == "Killed" || $0 == "Timeout" }.count
        let undetected = statuses.filter { $0 == "Survived" || $0 == "NoCoverage" }.count
        let valid = detected + undetected
        try #require(valid > 0)
        return Double(detected) / Double(valid) * 100.0
    }
}
