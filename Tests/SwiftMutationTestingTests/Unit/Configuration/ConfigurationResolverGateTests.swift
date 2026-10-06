import Foundation
import Testing

@testable import SwiftMutationTesting

@Suite("ConfigurationResolver — quality gate")
struct ConfigurationResolverGateTests {
    private let resolver = ConfigurationResolver()

    @Test("Given no gate settings, when resolved, then the gate is inactive")
    func noSettingsLeaveTheGateInactive() throws {
        let result = try resolver.resolve(cliArguments: arguments(), fileValues: [:])

        #expect(!result.gate.isActive)
        #expect(result.gate.writeBaselinePath == nil)
    }

    @Test("Given the gate keys in the config file, when resolved, then the policy and baseline come from the file")
    func readsTheGateFromTheFile() throws {
        let dir = try projectWithBaseline()
        defer { FileHelpers.cleanup(dir) }

        let result = try resolver.resolve(
            cliArguments: arguments(projectPath: dir.path),
            fileValues: ["min-score": "80", "baseline": "b.json", "max-score-drop": "1.5", "max-new-survivors": "0"]
        )

        #expect(result.gate.policy == GatePolicy(minScore: 80, maxScoreDrop: 1.5, maxNewSurvivors: 0))
        #expect(result.gate.baselinePath == dir.appendingPathComponent("b.json").standardizedFileURL.path)
        #expect(result.gate.isActive)
    }

    @Test("Given a maximum of integrity warnings and no baseline, when resolved, then the gate is active")
    func integrityWarningsNeedNoBaseline() throws {
        let fromFile = try resolver.resolve(cliArguments: arguments(), fileValues: ["max-integrity-warnings": "0"])
        var cli = arguments()
        cli.gate.maxIntegrityWarnings = 3
        let fromCLI = try resolver.resolve(cliArguments: cli, fileValues: ["max-integrity-warnings": "0"])

        #expect(fromFile.gate.policy == GatePolicy(maxIntegrityWarnings: 0))
        #expect(fromFile.gate.isActive)
        #expect(fromCLI.gate.policy.maxIntegrityWarnings == 3)
    }

    @Test("Given gate settings in both places, when resolved, then the command line wins")
    func commandLineOverridesTheFile() throws {
        var cli = arguments()
        cli.gate.minScore = 90

        let result = try resolver.resolve(cliArguments: cli, fileValues: ["min-score": "50"])

        #expect(result.gate.policy.minScore == 90)
    }

    @Test("Given relative baseline paths, when resolved, then they are relative to the project")
    func resolvesPathsAgainstTheProject() throws {
        let dir = try projectWithBaseline()
        defer { FileHelpers.cleanup(dir) }
        var cli = arguments(projectPath: dir.path)
        cli.gate.baseline = "b.json"
        cli.gate.writeBaseline = "out/next.json"

        let result = try resolver.resolve(cliArguments: cli, fileValues: [:])

        #expect(result.gate.baselinePath == dir.appendingPathComponent("b.json").standardizedFileURL.path)
        #expect(result.gate.writeBaselinePath == dir.appendingPathComponent("out/next.json").standardizedFileURL.path)
    }

    @Test("Given an absolute write-baseline path, when resolved, then it is kept")
    func keepsAbsolutePaths() throws {
        var cli = arguments()
        cli.gate.writeBaseline = "/abs/b.json"

        let result = try resolver.resolve(cliArguments: cli, fileValues: [:])

        #expect(result.gate.writeBaselinePath == "/abs/b.json")
        #expect(!result.gate.isActive)
    }

    @Test(
        "Given an invalid gate setting, when resolved, then a usage error explains it",
        arguments: [
            (["min-score": "101"], "between 0 and 100"),
            (["min-score": "many"], "min-score in .swift-mutation-testing.yml must be a number"),
            (["max-score-drop": "-1"], "--max-score-drop must be a number >= 0"),
            (["max-new-survivors": "-1"], "--max-new-survivors must be >= 0"),
            (["max-integrity-warnings": "-1"], "--max-integrity-warnings must be >= 0"),
            (["max-score-drop": "1"], "need --baseline"),
            (["max-new-survivors": "0"], "need --baseline"),
            (["baseline": "missing.json"], "does not exist"),
        ]
    )
    func rejectsInvalidSettings(fileValues: [String: String], message: String) {
        #expect {
            try resolver.resolve(cliArguments: arguments(), fileValues: fileValues)
        } throws: { error in
            (error as? UsageError)?.message.contains(message) == true
        }
    }

    private func arguments(projectPath: String = "/tmp") -> ParsedArguments {
        ParsedArguments(projectPath: projectPath, build: .init(scheme: "App", destination: "platform=macOS"))
    }

    private func projectWithBaseline() throws -> URL {
        let dir = try FileHelpers.makeTemporaryDirectory()
        try BaselineStore().write(makeBaseline(), to: dir.appendingPathComponent("b.json").path)
        return dir
    }
}
