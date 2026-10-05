import Foundation
import Testing

@testable import SwiftMutationTesting

@Suite("SwiftMutationTesting plan and run --plan", .serialized)
struct SwiftMutationTestingPlanTests {
    @Test("Given the plan command, when run, then the plan is written and the console says so")
    func planWritesThePlan() async throws {
        let dir = try FileHelpers.makeTemporaryDirectory()
        defer { FileHelpers.cleanup(dir) }
        try Self.writeProject(in: dir)
        let planPath = dir.appendingPathComponent("plan.json").path

        var result: ExitCode = .error
        let output = await captureOutput {
            result = await SwiftMutationTesting.run(args: ["plan", dir.path, "--output", planPath])
        }

        #expect(result == .success)
        #expect(output.contains("Plan: \(planPath) (2 mutants in 1 files)"))
        let plan = try PlanStore().read(from: planPath)
        #expect(plan.mutants.count == 2)
        #expect(plan.scope.operators == DiscoveryPipeline.operatorNames(upTo: .default))
        #expect(plan.project.type == "spm")
    }

    @Test("Given a plan whose file changed, when run --plan, then the run refuses with the file's name")
    func aStalePlanRefusesToRun() async throws {
        let dir = try FileHelpers.makeTemporaryDirectory()
        defer { FileHelpers.cleanup(dir) }
        try Self.writeProject(in: dir)
        let planPath = dir.appendingPathComponent("plan.json").path
        _ = await SwiftMutationTesting.run(args: ["plan", dir.path, "--output", planPath, "--quiet"])
        try "func f(_ a: Bool, _ b: Bool) -> Bool { a || b }\n".write(
            to: dir.appendingPathComponent("Foo.swift"), atomically: true, encoding: .utf8
        )

        let result = await SwiftMutationTesting.run(
            args: ["run", dir.path, "--plan", planPath, "--quiet"], launcher: MockProcessLauncher(exitCode: 1)
        )

        #expect(result == .error)
        let plan = try PlanStore().read(from: planPath)
        #expect(throws: PlanError.stale(file: "Foo.swift")) {
            try PlanMaterializer().load(plan: plan, projectPath: dir.path)
        }
    }

    @Test("Given a plan, when run --plan with a shard, then only that shard's mutants run and the report says which")
    func aShardRunsItsMutantsAndNamesItself() async throws {
        let dir = try FileHelpers.makeTemporaryDirectory()
        defer { FileHelpers.cleanup(dir) }
        try Self.writeProject(in: dir)
        try "func g(_ a: Bool, _ b: Bool) -> Bool { a || b }\n".write(
            to: dir.appendingPathComponent("Bar.swift"), atomically: true, encoding: .utf8
        )
        let planPath = dir.appendingPathComponent("plan.json").path
        _ = await SwiftMutationTesting.run(args: ["plan", dir.path, "--output", planPath, "--quiet"])
        let plan = try PlanStore().read(from: planPath)
        let reportPath = dir.appendingPathComponent("r.json").path

        let launcher = RecordingProcessLauncher(responses: [(0, "")])
        let result = await SwiftMutationTesting.run(
            args: ["run", dir.path, "--plan", planPath, "--shard", "2/2", "--quiet", "--output", reportPath, "--no-cache"],
            launcher: launcher
        )

        #expect(result == .success)
        let tested = await launcher.requests.compactMap { $0.additionalEnvironment["__SWIFT_MUTATION_TESTING_ACTIVE"] }
            .filter { !$0.isEmpty }
        let expected = ShardSelector.mutants(of: plan, in: Shard(index: 2, count: 2))
        #expect(!expected.isEmpty)
        #expect(Set(tested) == Set(expected.map { Plan.mutantID(at: plan.mutants.firstIndex(of: $0)!) }))

        let data = try Data(contentsOf: URL(fileURLWithPath: reportPath))
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let config = json?["config"] as? [String: Any]
        #expect(config?["planSha256"] as? String == (try PlanStore.sha256(of: plan)))
        #expect(config?["shard"] as? String == "2/2")
    }

    @Test("Given a plain run, when reported, then the report carries the hash of the plan it made")
    func aPlainRunHasAPlanToo() async throws {
        let dir = try FileHelpers.makeTemporaryDirectory()
        defer { FileHelpers.cleanup(dir) }
        try Self.writeProject(in: dir)
        let reportPath = dir.appendingPathComponent("r.json").path
        let planPath = dir.appendingPathComponent("plan.json").path
        _ = await SwiftMutationTesting.run(args: ["plan", dir.path, "--output", planPath, "--quiet"])

        let result = await SwiftMutationTesting.run(
            args: ["run", dir.path, "--quiet", "--output", reportPath, "--no-cache"],
            launcher: MockProcessLauncher(exitCode: 1)
        )

        #expect(result == .success)
        let data = try Data(contentsOf: URL(fileURLWithPath: reportPath))
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let config = json?["config"] as? [String: Any]
        #expect(config?["planSha256"] as? String == (try PlanStore.sha256(of: PlanStore().read(from: planPath))))
        #expect(config?["shard"] == nil)
    }

    static func writeProject(in dir: URL) throws {
        try "func f(_ a: Bool, _ b: Bool) -> Bool { a && b }\nfunc h(_ x: Int) -> Bool { x > 0 ? true : false }\n".write(
            to: dir.appendingPathComponent("Foo.swift"), atomically: true, encoding: .utf8
        )
        try "// swift-tools-version: 5.9\nimport PackageDescription\nlet package = Package(name: \"P\")\n".write(
            to: dir.appendingPathComponent("Package.swift"), atomically: true, encoding: .utf8
        )
    }
}
