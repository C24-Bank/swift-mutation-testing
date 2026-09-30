import Testing

@testable import SwiftMutationTesting

@Suite("CommandLineParser — quality gate")
struct CommandLineParserGateTests {
    private let parser = CommandLineParser()

    @Test("Given every gate flag, when parsed, then each value is set")
    func parsesEveryGateFlag() throws {
        let result = try parser.parse([
            "/p", "--min-score", "85.5", "--baseline", "b.json", "--max-score-drop", "0",
            "--max-new-survivors", "0", "--write-baseline", "new.json",
        ])

        #expect(result.gate.minScore == 85.5)
        #expect(result.gate.baseline == "b.json")
        #expect(result.gate.maxScoreDrop == 0)
        #expect(result.gate.maxNewSurvivors == 0)
        #expect(result.gate.writeBaseline == "new.json")
    }

    @Test(
        "Given a gate flag with an invalid value, when parsed, then a usage error names the flag",
        arguments: [
            ["--min-score", "high"],
            ["--min-score", "-1"],
            ["--max-score-drop", "-0.5"],
            ["--max-new-survivors", "1.5"],
            ["--baseline"],
        ]
    )
    func rejectsInvalidValues(arguments: [String]) {
        #expect {
            try parser.parse(arguments)
        } throws: { error in
            (error as? UsageError)?.message.contains(arguments[0]) == true
        }
    }
}
