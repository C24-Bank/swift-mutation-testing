import Foundation
import Testing

@testable import SwiftMutationTesting

@Suite(.tags(.integration), .serialized, .notInsideAMutationRun)
struct PlanShardMergeIntegrationTests {
    @Test("Given a package planned and run in two shards, when merged, then every verdict is the single run's")
    func twoShardsMergedAreTheSingleRun() async throws {
        let fixture = try FixtureCopy.make("CalcLibrary")
        defer { fixture.remove() }
        let root = fixture.url.path
        let planPath = fixture.url.appendingPathComponent("plan.json").path
        let paths = ["single", "one", "two", "merged"].map { fixture.url.appendingPathComponent("\($0).json").path }

        let plan = await SwiftMutationTesting.run(
            args: ["plan", root, "--output", planPath, "--quiet", "--operator-tier", "experimental"]
        )
        #expect(plan == .success)
        for (arguments, path) in [([], paths[0]), (["--shard", "1/2"], paths[1]), (["--shard", "2/2"], paths[2])] {
            let result = await SwiftMutationTesting.run(
                args: ["run", root, "--plan", planPath, "--quiet", "--no-cache", "--output", path] + arguments
            )
            #expect(result == .success)
        }
        let merge = await SwiftMutationTesting.run(
            args: ["merge", paths[1], paths[2], "--plan", planPath, "--output", paths[3], "--quiet"]
        )

        #expect(merge == .success)
        let single = try verdicts(at: paths[0])
        let merged = try verdicts(at: paths[3])
        #expect(merged == single)
        let planned = try PlanStore().read(from: planPath).mutants.count
        #expect(single.count == planned)
        #expect(Set(single.values).isSuperset(of: ["Killed", "Survived"]))
    }

    private func verdicts(at path: String) throws -> [String: String] {
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        let payload = try JSONDecoder().decode(MutationReportPayload.self, from: data)
        return Dictionary(
            uniqueKeysWithValues: payload.files.values.flatMap(\.mutants).map { ($0.fingerprint, $0.status) }
        )
    }
}
