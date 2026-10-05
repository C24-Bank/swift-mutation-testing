import Testing

@testable import SwiftMutationTesting

@Suite("ShardSelector")
struct ShardSelectorTests {
    @Test("Given i/n, when parsed, then a shard inside its range is accepted and the rest refused")
    func parsing() {
        #expect(Shard(parsing: "1/1") == Shard(index: 1, count: 1))
        #expect(Shard(parsing: "3/4") == Shard(index: 3, count: 4))
        #expect(Shard(parsing: "3/4")?.description == "3/4")
        for raw in ["0/4", "5/4", "4", "a/b", "1/0", "", "1/2/3", "-1/2"] {
            #expect(Shard(parsing: raw) == nil, "\(raw)")
        }
    }

    @Test("Given a plan sharded in n, when every shard is selected, then the union is the plan and nothing overlaps")
    func theShardsPartitionThePlan() {
        let plan = Self.plan(countsByFile: ["A": 5, "B": 1, "C": 3, "D": 3, "E": 2])

        let shards = (1 ... 3).map { ShardSelector.mutants(of: plan, in: Shard(index: $0, count: 3)) }

        #expect(shards.flatMap { $0 }.count == plan.mutants.count)
        #expect(Set(shards.flatMap { $0.map(\.fingerprint) }).count == plan.mutants.count)
        for shard in shards {
            #expect(shard.map(\.fingerprint) == plan.mutants.filter { m in shard.contains { $0.file == m.file } }.map(\.fingerprint))
        }
    }

    @Test("Given files in path order, when assigned, then each goes to the lightest shard, ties to the lowest")
    func filesGoToTheLightestShard() {
        let plan = Self.plan(countsByFile: ["A": 5, "B": 1, "C": 3, "D": 3, "E": 2])

        #expect(ShardSelector.files(of: plan, in: Shard(index: 1, count: 3)) == ["A"])
        #expect(ShardSelector.files(of: plan, in: Shard(index: 2, count: 3)) == ["B", "D"])
        #expect(ShardSelector.files(of: plan, in: Shard(index: 3, count: 3)) == ["C", "E"])
    }

    @Test("Given the same plan and n, when selected twice, then the partition is the same")
    func thePartitionIsDeterministic() {
        let plan = Self.plan(countsByFile: ["A": 2, "B": 2, "C": 2, "D": 2])

        let once = (1 ... 4).map { ShardSelector.files(of: plan, in: Shard(index: $0, count: 4)) }
        let again = (1 ... 4).map { ShardSelector.files(of: plan, in: Shard(index: $0, count: 4)) }

        #expect(once == again)
        #expect(once == [["A"], ["B"], ["C"], ["D"]])
    }

    @Test("Given more shards than files, when selected, then the extra shards are empty")
    func extraShardsAreEmpty() {
        let plan = Self.plan(countsByFile: ["A": 9])

        #expect(ShardSelector.mutants(of: plan, in: Shard(index: 1, count: 2)).count == 9)
        #expect(ShardSelector.mutants(of: plan, in: Shard(index: 2, count: 2)).isEmpty)
    }

    static func plan(countsByFile: [String: Int]) -> Plan {
        var mutants: [Plan.Mutant] = []
        for (file, count) in countsByFile.sorted(by: { $0.key < $1.key }) {
            for offset in 0 ..< count {
                mutants.append(
                    Plan.Mutant(
                        fingerprint: "\(file)-\(offset)", file: file, utf8Start: offset, utf8End: offset + 1, line: 1,
                        column: offset + 1, operator: "SwapTernary", replacementKind: .swapTernary, original: "a",
                        replacement: "b", description: "", schematizable: true
                    )
                )
            }
        }
        return Plan(
            formatVersion: Plan.formatVersion, toolVersion: "0",
            project: Plan.Project(type: .spm, testTarget: nil),
            scope: Plan.Scope(sourcesPath: ".", excludePatterns: [], operators: ["SwapTernary"]),
            files: countsByFile.keys.sorted().map { Plan.File(path: $0, sha256: "") }, mutants: mutants
        )
    }
}
