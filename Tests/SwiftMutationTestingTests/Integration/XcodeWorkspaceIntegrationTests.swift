import Foundation
import Testing

@testable import SwiftMutationTesting

@Suite(.tags(.integration), .serialized, .notInsideAMutationRun)
struct XcodeWorkspaceIntegrationTests {
    @Test(
        "Given a workspace of two projects, one with a SwiftLint phase, when run, then one build tests every mutant of both"
    )
    func bothProjectsAreSchematizedInOneBuild() async throws {
        let fixture = try FixtureCopy.make("CalcWorkspace")
        defer { fixture.remove() }
        let reportPath = fixture.url.appendingPathComponent("r.json").path
        let launcher = CountingLauncher(wrapping: XcodeProcessLauncher())

        let result = await SwiftMutationTesting.run(
            args: [
                fixture.url.path, "--scheme", "CalcWorkspace", "--destination", "platform=macOS", "--no-cache",
                "--quiet", "--operator-tier", "experimental", "--output", reportPath,
            ],
            launcher: launcher
        )

        #expect(result == .success)
        let builds = await launcher.requests.filter { $0.arguments.first == "build-for-testing" }
        #expect(builds.count == 1)
        #expect(builds.first?.arguments.suffix(2) == ["-workspace", "CalcWorkspace.xcworkspace"])
        let statuses = try Self.statusesByFile(at: reportPath)
        #expect(
            Set(statuses.keys) == [
                "/AppProject/Sources/Greeter.swift", "/AppProject/Sources/Formatter.swift",
                "/CoreProject/Sources/Adder.swift", "/CoreProject/Sources/Range.swift",
            ])
        #expect(statuses.values.allSatisfy { !$0.contains("CompileError") })
        #expect(statuses.values.allSatisfy { $0.contains("Killed") })
    }

    @Test("Given a workspace, when init writes the file, then a run with no flag builds the workspace")
    func initWritesAFileThatRunsAsIs() async throws {
        let fixture = try FixtureCopy.make("CalcWorkspace")
        defer { fixture.remove() }

        let initialized = await SwiftMutationTesting.run(args: ["init", fixture.url.path])
        #expect(initialized == .success)
        let values = try ConfigurationFileParser().parse(at: fixture.url.path)
        #expect(values["workspace"] == "CalcWorkspace.xcworkspace")
        #expect(values["scheme"] == "CalcWorkspace")
        #expect(values["destination"] == "platform=macOS")
        #expect(values["test-target"] == nil)

        let launcher = CountingLauncher(wrapping: XcodeProcessLauncher())
        // The generated file's `output:` is relative to the working directory; keep the report in the copy.
        let reportPath = fixture.url.appendingPathComponent("r.json").path
        let result = await SwiftMutationTesting.run(
            args: [fixture.url.path, "--no-cache", "--quiet", "--output", reportPath], launcher: launcher
        )

        #expect(result == .success)
        let builds = await launcher.requests.filter { $0.arguments.first == "build-for-testing" }
        #expect(builds.map { Array($0.arguments.suffix(2)) } == [["-workspace", "CalcWorkspace.xcworkspace"]])
    }

    @Test("Given the workspace beside a second one, when run without a container, then the run is refused naming both")
    func twoWorkspacesAreNeverChosenSilently() async throws {
        let fixture = try FixtureCopy.make("CalcWorkspace")
        defer { fixture.remove() }
        try FileManager.default.copyItem(
            at: fixture.url.appendingPathComponent("CalcWorkspace.xcworkspace"),
            to: fixture.url.appendingPathComponent("Tools.xcworkspace")
        )
        let launcher = CountingLauncher(wrapping: XcodeProcessLauncher())

        let result = await SwiftMutationTesting.run(
            args: [fixture.url.path, "--scheme", "CalcWorkspace", "--destination", "platform=macOS", "--quiet"],
            launcher: launcher
        )

        #expect(result == .error)
        #expect(await launcher.requests.isEmpty)
    }

    static func statusesByFile(at path: String) throws -> [String: [String]] {
        let payload = try JSONDecoder().decode(
            MutationReportPayload.self, from: Data(contentsOf: URL(fileURLWithPath: path))
        )
        return payload.files.mapValues { $0.mutants.map(\.status) }
    }
}
