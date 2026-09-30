import Foundation
import Testing

@testable import SwiftMutationTesting

@Suite("SwiftMutationTesting.writeReports", .serialized)
struct WriteReportsTests {
    @Test("Given no output paths configured, when writeReports called, then no files are created")
    func noOutputPathsProducesNoFiles() throws {
        let dir = try FileHelpers.makeTemporaryDirectory()
        defer { FileHelpers.cleanup(dir) }

        let configuration = makeRunnerConfiguration(projectPath: dir.path)

        SwiftMutationTesting.writeReports(makeEmptySummary(), configuration: configuration)

        let files = try FileManager.default.contentsOfDirectory(atPath: dir.path)
        #expect(files.isEmpty)
    }

    @Test("Given json output path, when writeReports called, then json file is written")
    func jsonOutputPathWritesFile() throws {
        let dir = try FileHelpers.makeTemporaryDirectory()
        defer { FileHelpers.cleanup(dir) }

        let outputPath = dir.appendingPathComponent("report.json").path
        let configuration = makeRunnerConfiguration(projectPath: dir.path, output: outputPath)

        SwiftMutationTesting.writeReports(makeEmptySummary(), configuration: configuration)

        #expect(FileManager.default.fileExists(atPath: outputPath))
    }

    @Test("Given html output path, when writeReports called, then html file is written")
    func htmlOutputPathWritesFile() throws {
        let dir = try FileHelpers.makeTemporaryDirectory()
        defer { FileHelpers.cleanup(dir) }

        let outputPath = dir.appendingPathComponent("report.html").path
        let configuration = makeRunnerConfiguration(projectPath: dir.path, htmlOutput: outputPath)

        SwiftMutationTesting.writeReports(makeEmptySummary(), configuration: configuration)

        #expect(FileManager.default.fileExists(atPath: outputPath))
    }

    @Test("Given sonar output path, when writeReports called, then sonar file is written")
    func sonarOutputPathWritesFile() throws {
        let dir = try FileHelpers.makeTemporaryDirectory()
        defer { FileHelpers.cleanup(dir) }

        let outputPath = dir.appendingPathComponent("sonar.json").path
        let configuration = makeRunnerConfiguration(projectPath: dir.path, sonarOutput: outputPath)

        SwiftMutationTesting.writeReports(makeEmptySummary(), configuration: configuration)

        #expect(FileManager.default.fileExists(atPath: outputPath))
    }

    @Test("Given invalid json output path, when writeReports called, then does not crash")
    func invalidJsonOutputPathDoesNotCrash() {
        let configuration = makeRunnerConfiguration(
            projectPath: "/tmp",
            output: "/nonexistent/dir/report.json"
        )
        SwiftMutationTesting.writeReports(makeEmptySummary(), configuration: configuration)
    }

    @Test("Given invalid html output path, when writeReports called, then does not crash")
    func invalidHtmlOutputPathDoesNotCrash() {
        let configuration = makeRunnerConfiguration(
            projectPath: "/tmp",
            htmlOutput: "/nonexistent/dir/report.html"
        )
        SwiftMutationTesting.writeReports(makeEmptySummary(), configuration: configuration)
    }

    @Test("Given invalid sonar output path, when writeReports called, then does not crash")
    func invalidSonarOutputPathDoesNotCrash() {
        let configuration = makeRunnerConfiguration(
            projectPath: "/tmp",
            sonarOutput: "/nonexistent/dir/sonar.json"
        )
        SwiftMutationTesting.writeReports(makeEmptySummary(), configuration: configuration)
    }

    @Test("Given all three output paths, when writeReports called, then all three files are written")
    func allThreeOutputPathsWriteFiles() throws {
        let dir = try FileHelpers.makeTemporaryDirectory()
        defer { FileHelpers.cleanup(dir) }

        let jsonPath = dir.appendingPathComponent("report.json").path
        let htmlPath = dir.appendingPathComponent("report.html").path
        let sonarPath = dir.appendingPathComponent("sonar.json").path
        let configuration = makeRunnerConfiguration(
            projectPath: dir.path,
            output: jsonPath,
            htmlOutput: htmlPath,
            sonarOutput: sonarPath
        )

        SwiftMutationTesting.writeReports(makeEmptySummary(), configuration: configuration)

        #expect(FileManager.default.fileExists(atPath: jsonPath))
        #expect(FileManager.default.fileExists(atPath: htmlPath))
        #expect(FileManager.default.fileExists(atPath: sonarPath))
    }

    @Test("Given SARIF and Markdown output paths, when writeReports called, then both files are written")
    func sarifAndMarkdownOutputPathsWriteFiles() throws {
        let dir = try FileHelpers.makeTemporaryDirectory()
        defer { FileHelpers.cleanup(dir) }

        let sarifPath = dir.appendingPathComponent("report.sarif").path
        let markdownPath = dir.appendingPathComponent("summary.md").path
        let configuration = makeRunnerConfiguration(
            projectPath: dir.path, sarifOutput: sarifPath, markdownOutput: markdownPath
        )

        let output = captureOutputSync {
            SwiftMutationTesting.writeReports(makeEmptySummary(), configuration: configuration)
        }

        #expect(FileManager.default.fileExists(atPath: sarifPath))
        #expect(FileManager.default.fileExists(atPath: markdownPath))
        #expect(output.contains("  ✓ SARIF report: \(sarifPath)"))
        #expect(output.contains("  ✓ Markdown report: \(markdownPath)"))
    }

    @Test("Given a gate result, when writeReports called, then the Markdown summary includes the gate")
    func markdownIncludesTheGate() throws {
        let dir = try FileHelpers.makeTemporaryDirectory()
        defer { FileHelpers.cleanup(dir) }

        let markdownPath = dir.appendingPathComponent("summary.md").path
        let configuration = makeRunnerConfiguration(projectPath: dir.path, markdownOutput: markdownPath)
        let gate = GateResult(checks: [.minScore(score: 100, minimum: 80)], newUndetected: [], fixedCount: nil)

        _ = captureOutputSync {
            SwiftMutationTesting.writeReports(makeEmptySummary(), configuration: configuration, gate: gate)
        }

        let markdown = try String(contentsOfFile: markdownPath, encoding: .utf8)
        #expect(markdown.contains("### Quality gate: passed ✅"))
        #expect(markdown.contains("- ✓ score 100.0% ≥ 80.0%"))
    }

    @Test("Given no gate settings, when the gate is evaluated, then there is no result")
    func inactiveGateHasNoResult() {
        let result = SwiftMutationTesting.evaluateGate(
            makeEmptySummary(), configuration: makeRunnerConfiguration(), baseline: nil
        )

        #expect(result == nil)
    }
}
