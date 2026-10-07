import Foundation
import Testing

@testable import SwiftMutationTesting

@Suite("SwiftMutationTesting.command(for:)")
struct CommandDispatchTests {

    @Test(
        "Given each command word, when dispatched, then the command of that kind runs it",
        arguments: [
            (["--help"], "HelpCommand"),
            (["--version"], "VersionCommand"),
            (["init", "/tmp"], "InitCommand"),
            (["plan", "/tmp"], "PlanCommand"),
            (["merge", "r.json", "--plan", "p.json", "--project-path", "/tmp"], "MergeCommand"),
            (["reproduce", "swift-mutation-testing_0", "/tmp"], "ReproduceCommand"),
            (["/tmp"], "RunCommand"),
        ]
    )
    func eachWordGetsItsCommand(arguments: [String], kind: String) throws {
        let dir = try FileHelpers.makeTemporaryDirectory()
        defer { FileHelpers.cleanup(dir) }
        try FileHelpers.write("// swift-tools-version: 6.0", named: "Package.swift", in: dir)
        let parsed = try CommandLineParser().parse(arguments.map { $0 == "/tmp" ? dir.path : $0 })

        let command = try SwiftMutationTesting.command(for: parsed, launcher: MockProcessLauncher(exitCode: 0))

        #expect(String(describing: type(of: command)) == kind)
    }
}
