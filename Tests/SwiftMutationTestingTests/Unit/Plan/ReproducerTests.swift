import Foundation
import Testing

@testable import SwiftMutationTesting

@Suite("Reproducer", .serialized)
struct ReproducerTests {
    @Test("Given an id, a fingerprint or a unique prefix, when resolved, then the mutant is found; else refused")
    func references() throws {
        let plan = ShardSelectorTests.plan(countsByFile: ["A": 2, "B": 1])

        #expect(try Reproducer.mutant(matching: "swift-mutation-testing_2", in: plan).0 == 2)
        #expect(try Reproducer.mutant(matching: "B-0", in: plan).1.fingerprint == "B-0")
        #expect(throws: PlanError.unknownMutant("swift-mutation-testing_3")) {
            try Reproducer.mutant(matching: "swift-mutation-testing_3", in: plan)
        }
        #expect(throws: PlanError.unknownMutant("A-")) { try Reproducer.mutant(matching: "A-", in: plan) }
        #expect(throws: PlanError.unknownMutant("zzzzzz")) { try Reproducer.mutant(matching: "zzzzzz", in: plan) }
    }

    @Test(
        "Given a mutant, when reproduced, then the whole suite runs without a stop rule, the sandbox stays and everything is printed"
    )
    func reproduceRunsTheWholeSuiteAndKeepsTheSandbox() async throws {
        let dir = try FileHelpers.makeTemporaryDirectory()
        defer { FileHelpers.cleanup(dir) }
        try SwiftMutationTestingPlanTests.writeProject(in: dir)
        let plan = try await Planner().plan(input: Self.input(for: dir)).plan
        let launcher = RecordingProcessLauncher(responses: [(0, "")])
        let configuration = makeRunnerConfiguration(projectPath: dir.path, projectType: .spm, timeout: 30)

        var exit: ExitCode = .error
        let output = await captureOutput {
            exit =
                (try? await Reproducer().reproduce(
                    "swift-mutation-testing_1", plan: plan, configuration: configuration, launcher: launcher
                )) ?? .error
        }
        let sandboxes = output.split(separator: "\n").filter { $0.hasPrefix("Sandbox: ") }.map {
            String($0.dropFirst(9))
        }
        defer { for sandbox in sandboxes { try? FileManager.default.removeItem(atPath: sandbox) } }

        #expect(exit == .success)
        #expect(output.contains("Reproducing swift-mutation-testing_1 (\(plan.mutants[1].fingerprint))"))
        #expect(sandboxes.count == 1)
        #expect(FileManager.default.fileExists(atPath: sandboxes[0]))
        #expect(output.contains("--- Foo.swift:2"))
        #expect(output.contains("-2: func h(_ x: Int) -> Bool { x > 0 ? true : false }"))
        #expect(output.contains("+2: func h(_ x: Int) -> Bool { x > 0 ? false : true }"))
        #expect(output.contains("Tests:"))
        #expect(output.contains("Verdict: "))

        let tests = await launcher.requests.filter {
            $0.additionalEnvironment["__SWIFT_MUTATION_TESTING_ACTIVE"] == "swift-mutation-testing_1"
        }
        #expect(!tests.isEmpty)
        #expect(tests.allSatisfy { $0.stopRule == nil })
        #expect(tests.allSatisfy { !$0.arguments.contains("--filter") })
    }

    static func input(for dir: URL) -> DiscoveryInput {
        makeDiscoveryInput(
            projectPath: dir.path, projectType: .spm, sourcesPath: dir.path,
            operators: OperatorRegistry.operatorNames(upTo: .standard)
        )
    }
}
