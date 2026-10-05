import Foundation
import Testing

@testable import SwiftMutationTesting

@Suite("Planner")
struct PlannerTests {
    @Test("Given the same code in two directories, when planned, then the plans are the same bytes")
    func thePlanDoesNotDependOnWhereTheCodeIs() async throws {
        let first = try FileHelpers.makeTemporaryDirectory()
        defer { FileHelpers.cleanup(first) }
        let second = try FileHelpers.makeTemporaryDirectory()
        defer { FileHelpers.cleanup(second) }
        for dir in [first, second] {
            try writeProject(in: dir)
        }

        let one = try PlanStore.encode(try await Planner().plan(input: input(for: first)).plan)
        let other = try PlanStore.encode(try await Planner().plan(input: input(for: second)).plan)

        #expect(one == other)
        #expect(!String(decoding: one, as: UTF8.self).contains(first.path))
    }

    @Test("Given a project, when planned twice, then the plans are the same bytes")
    func planningIsDeterministic() async throws {
        let dir = try FileHelpers.makeTemporaryDirectory()
        defer { FileHelpers.cleanup(dir) }
        try writeProject(in: dir)

        let one = try PlanStore.encode(try await Planner().plan(input: input(for: dir)).plan)
        let other = try PlanStore.encode(try await Planner().plan(input: input(for: dir)).plan)

        #expect(one == other)
    }

    @Test("Given a project, when planned, then the plan holds relative paths, hashes and the mutants in order")
    func thePlanDescribesTheProject() async throws {
        let dir = try FileHelpers.makeTemporaryDirectory()
        defer { FileHelpers.cleanup(dir) }
        try writeProject(in: dir)

        let plan = try await Planner().plan(input: input(for: dir), testTarget: "CalcTests").plan

        #expect(plan.formatVersion == Plan.formatVersion)
        #expect(plan.toolVersion == Version.number)
        #expect(plan.project.type == "spm")
        #expect(plan.project.testTarget == "CalcTests")
        #expect(plan.scope.sourcesPath == "Sources")
        #expect(plan.scope.operators == ["BooleanLiteralReplacement", "LogicalOperatorReplacement"])
        #expect(plan.files.map(\.path) == ["Sources/A.swift", "Sources/B.swift"])
        #expect(
            plan.files.map(\.sha256) == [MutantCacheKey.hash(of: Self.fileA), MutantCacheKey.hash(of: Self.fileB)]
        )
        #expect(plan.mutants.map(\.file) == ["Sources/A.swift", "Sources/B.swift", "Sources/B.swift"])
        #expect(
            plan.mutants.map(\.operator) == [
                "BooleanLiteralReplacement", "LogicalOperatorReplacement", "BooleanLiteralReplacement",
            ]
        )
        #expect(plan.mutants.map { $0.utf8End - $0.utf8Start } == plan.mutants.map { $0.original.utf8.count })
        #expect(plan.mutants.map(\.schematizable) == [true, true, false])
        #expect(plan.mutants.allSatisfy { !$0.fingerprint.isEmpty })
    }

    @Test("Given a project at its root, when planned with no sources path, then the scope says \".\"")
    func theRootScopeIsADot() async throws {
        let dir = try FileHelpers.makeTemporaryDirectory()
        defer { FileHelpers.cleanup(dir) }
        try writeProject(in: dir)

        let plan = try await Planner().plan(
            input: makeDiscoveryInput(projectPath: dir.path, sourcesPath: dir.path, operators: [])
        ).plan

        #expect(plan.scope.sourcesPath == ".")
        #expect(plan.scope.operators == DiscoveryPipeline.allOperatorNames)
    }

    // MARK: - Fixture

    static let fileA = "func a() -> Bool { true }\n"
    static let fileB = "func b(_ x: Bool, _ y: Bool) -> Bool { x && y }\nlet flag = false\n"

    private func writeProject(in dir: URL) throws {
        let sources = dir.appendingPathComponent("Sources")
        try FileManager.default.createDirectory(at: sources, withIntermediateDirectories: true)
        try Self.fileA.write(to: sources.appendingPathComponent("A.swift"), atomically: true, encoding: .utf8)
        try Self.fileB.write(to: sources.appendingPathComponent("B.swift"), atomically: true, encoding: .utf8)
    }

    private func input(for dir: URL) -> DiscoveryInput {
        makeDiscoveryInput(
            projectPath: dir.path, projectType: .spm, sourcesPath: dir.appendingPathComponent("Sources").path,
            operators: ["BooleanLiteralReplacement", "LogicalOperatorReplacement"]
        )
    }

    @Test("Given an Xcode container, when planned, then the plan carries it; a package plan has no such key")
    func theContainerIsInThePlan() async throws {
        let dir = try FileHelpers.makeTemporaryDirectory()
        defer { FileHelpers.cleanup(dir) }
        try writeProject(in: dir)

        let xcode = try await Planner().plan(
            input: makeDiscoveryInput(
                projectPath: dir.path, projectType: .xcode(scheme: "App", destination: "platform=macOS"),
                sourcesPath: dir.path
            ),
            container: .workspace("Apps/App.xcworkspace")
        ).plan
        let package = try await Planner().plan(input: input(for: dir)).plan

        #expect(xcode.project.workspace == "Apps/App.xcworkspace")
        #expect(xcode.project.xcodeContainer == .workspace("Apps/App.xcworkspace"))
        let text = String(decoding: try PlanStore.encode(package), as: UTF8.self)
        #expect(!text.contains("workspace") && !text.contains("xcodeProject"))
        let applied = try makeRunnerConfiguration(projectPath: dir.path).applying(xcode)
        #expect(applied.build.xcodeContainer == .workspace("Apps/App.xcworkspace"))
    }
}
