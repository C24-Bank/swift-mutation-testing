import Foundation
import Testing

@testable import SwiftMutationTesting

@Suite(.tags(.integration), .serialized, .notInsideAMutationRun)
struct PlanShardMergeIntegrationTests {
    @Test(
        "Given a package planned on one copy and run as 4 shards on 4 others, when merged, then the report is the single run's"
    )
    func fourShardsOnFourCopiesMergeIntoTheSingleRun() async throws {
        let planner = try FixtureCopy.make("CalcLibrary")
        defer { planner.remove() }
        let planPath = planner.url.appendingPathComponent("plan.json").path
        let plan = await SwiftMutationTesting.run(
            args: ["plan", planner.url.path, "--output", planPath, "--quiet", "--operator-tier", "experimental"]
        )
        #expect(plan == .success)

        let single = try await run(planPath: planPath, shard: nil)
        var shards: [String] = []
        for index in 1 ... 4 {
            shards.append(try await run(planPath: planPath, shard: "\(index)/4"))
        }
        let merger = try FixtureCopy.make("CalcLibrary")
        defer { merger.remove() }
        let mergedPath = merger.url.appendingPathComponent("merged.json").path
        let merge = await SwiftMutationTesting.run(
            args: ["merge"] + shards + [
                "--plan", planPath, "--project-path", merger.url.path, "--output", mergedPath, "--quiet",
            ]
        )
        #expect(merge == .success)
        #expect(try Self.comparableReport(at: mergedPath) == Self.comparableReport(at: single))
        #expect(try Self.mutantCount(at: single) == PlanStore().read(from: planPath).mutants.count)
        #expect(Set(try Self.statuses(at: single)).isSuperset(of: ["Killed", "Survived"]))
    }

    private func run(planPath: String, shard: String?) async throws -> String {
        let machine = try FixtureCopy.make("CalcLibrary")
        let output = FileManager.default.temporaryDirectory
            .appendingPathComponent("plan-shard-\(UUID().uuidString).json").path
        let arguments =
            ["run", machine.url.path, "--plan", planPath, "--quiet", "--no-cache", "--output", output]
            + (shard.map { ["--shard", $0] } ?? [])
        let result = await SwiftMutationTesting.run(args: arguments)
        #expect(result == .success, "shard \(shard ?? "whole")")
        machine.remove()
        return output
    }

    static func comparableReport(at path: String) throws -> NSDictionary {
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        var json = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        json["projectRoot"] = nil
        var files = try #require(json["files"] as? [String: [String: Any]])
        for (key, var file) in files {
            let mutants = try #require(file["mutants"] as? [[String: Any]])
            file["mutants"] =
                mutants
                .map { mutant -> [String: Any] in
                    var mutant = mutant
                    mutant["duration"] = nil
                    return mutant
                }
                .sorted { ($0["id"] as? String ?? "") < ($1["id"] as? String ?? "") }
            files[key] = file
        }
        json["files"] = files
        return json as NSDictionary
    }

    static func mutantCount(at path: String) throws -> Int {
        try statuses(at: path).count
    }

    static func statuses(at path: String) throws -> [String] {
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        let payload = try JSONDecoder().decode(MutationReportPayload.self, from: data)
        return payload.files.values.flatMap(\.mutants).map(\.status)
    }
}
