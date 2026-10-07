import Foundation
import Testing

@testable import SwiftMutationTesting

@Suite("ReportFormat")
struct ReportFormatTests {

    @Test(
        "Given every format's flag, when parsed, then the path lands under that format",
        arguments: ReportFormat.allCases
    )
    func eachFlagParsesIntoItsFormat(format: ReportFormat) throws {
        let parsed = try CommandLineParser().parse([format.flag, "report.out"])

        #expect(parsed.reporting.outputs == [format: "report.out"])
    }

    @Test(
        "Given every format's file key, when resolved, then the path lands under that format",
        arguments: ReportFormat.allCases
    )
    func eachFileKeyResolvesIntoItsFormat(format: ReportFormat) throws {
        let dir = try FileHelpers.makeTemporaryDirectory()
        defer { FileHelpers.cleanup(dir) }
        try FileHelpers.write("// swift-tools-version: 6.0", named: "Package.swift", in: dir)
        let parsed = ParsedArguments(projectPath: dir.path)

        let configuration = try ConfigurationResolver().resolve(
            cliArguments: parsed, fileValues: [format.fileKey: "from-file.out"]
        )

        #expect(configuration.reporting.outputs == [format: "from-file.out"])
    }

    @Test("Given the formats, when their keys and help lines are read, then they follow the flags")
    func keysAndHelpLinesFollowTheFlags() {
        #expect(
            ReportFormat.allCases.map(\.fileKey) == [
                "output", "html-output", "sonar-output", "sarif-output", "markdown-output",
            ])
        #expect(ReportFormat.allCases.allSatisfy { HelpText.usage.contains($0.helpLine) })
        #expect(ReportFormat.named(flag: "--quiet") == nil)
    }
}
