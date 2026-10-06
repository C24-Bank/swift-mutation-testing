import Foundation
import Testing

@testable import SwiftMutationTesting

@Suite("PlanStore")
struct PlanStoreTests {
    @Test("Given a plan written, when read back, then it is equal and its bytes end with one newline")
    func writeAndReadRoundTrip() throws {
        let dir = try FileHelpers.makeTemporaryDirectory()
        defer { FileHelpers.cleanup(dir) }
        let path = dir.appendingPathComponent("plan.json").path

        try PlanStore().write(Self.plan, to: path)

        #expect(try PlanStore().read(from: path) == Self.plan)
        let text = try String(contentsOfFile: path, encoding: .utf8)
        #expect(text.hasSuffix("}\n") && !text.hasSuffix("\n\n"))
        #expect(text.contains("\"formatVersion\" : 1"))
        #expect(text.contains("Sources/A.swift") && !text.contains("\\/"))
    }

    @Test("Given a mutant in a plan, when encoded, then its operator is still under the key 'operator'")
    func theOperatorKeepsItsKeyInThePlan() throws {
        let text = String(decoding: try PlanStore.encode(Self.plan), as: UTF8.self)

        #expect(text.contains("\"operator\" : \"RelationalOperatorReplacement\""))
        #expect(!text.contains("operatorIdentifier"))
    }

    @Test("Given no file, when read, then the error says so")
    func aMissingPlanIsReported() throws {
        let path = "/tmp/xmr-no-plan-\(UUID().uuidString).json"

        #expect(throws: PlanError.notFound(path: path)) { try PlanStore().read(from: path) }
    }

    @Test("Given a file that is not a plan, when read, then it is unreadable")
    func aNonPlanIsUnreadable() throws {
        let dir = try FileHelpers.makeTemporaryDirectory()
        defer { FileHelpers.cleanup(dir) }
        let path = dir.appendingPathComponent("plan.json").path
        try "not json".write(toFile: path, atomically: true, encoding: .utf8)

        #expect(throws: PlanError.unreadable(path: path)) { try PlanStore().read(from: path) }
    }

    @Test("Given a plan of another format version, when read, then the version is named")
    func anotherVersionIsRefused() throws {
        let dir = try FileHelpers.makeTemporaryDirectory()
        defer { FileHelpers.cleanup(dir) }
        let path = dir.appendingPathComponent("plan.json").path
        try "{\"formatVersion\": 9}".write(toFile: path, atomically: true, encoding: .utf8)

        #expect(throws: PlanError.unsupportedVersion(path: path, version: 9)) { try PlanStore().read(from: path) }
    }

    @Test("Given a plan, when hashed, then the hash is that of its bytes and stable")
    func theHashIsOfTheBytes() throws {
        let bytes = try PlanStore.encode(Self.plan)

        #expect(try PlanStore.sha256(of: Self.plan) == MutantCacheKey.hash(of: String(decoding: bytes, as: UTF8.self)))
        #expect(try PlanStore.sha256(of: Self.plan) == PlanStore.sha256(of: Self.plan))
    }

    static let plan = Plan(
        formatVersion: Plan.formatVersion,
        toolVersion: "1.7.0",
        project: Plan.Project(type: .xcode(scheme: "App", destination: "platform=macOS"), testTarget: nil),
        scope: Plan.Scope(sourcesPath: "Sources", excludePatterns: ["/Generated/"], operators: ["SwapTernary"]),
        files: [Plan.File(path: "Sources/A.swift", sha256: "abc")],
        mutants: [
            Plan.Mutant(
                fingerprint: "3f2a", file: "Sources/A.swift", utf8Start: 10, utf8End: 11, line: 2, column: 5,
                operatorIdentifier: "RelationalOperatorReplacement", replacementKind: .binaryOperator, original: "<",
                replacement: "<=", description: "< → <=", schematizable: true
            )
        ]
    )
}
