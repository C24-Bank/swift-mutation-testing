/// One of `count` slices of a plan, `1 ≤ index ≤ count`, written `i/n` on the command line.
struct Shard: Sendable, Equatable, CustomStringConvertible {
    let index: Int
    let count: Int

    init?(parsing raw: String) {
        let parts = raw.split(separator: "/", omittingEmptySubsequences: false)
        guard
            parts.count == 2, let index = Int(parts[0]), let count = Int(parts[1]),
            count >= 1, index >= 1, index <= count
        else { return nil }
        self.index = index
        self.count = count
    }

    init(index: Int, count: Int) {
        self.index = index
        self.count = count
    }

    var description: String { "\(index)/\(count)" }
}

/// Splits a plan by file: every mutant of a file goes to one shard, so each shard builds one schema with
/// only its mutants and no file is built twice.
///
/// Files are taken in path order and each goes to the shard with the fewest mutants so far, ties to the
/// lowest index, so the same plan and the same `n` always give the same partition. A file with more
/// mutants than its share still goes whole to one shard: the balance is approximate.
enum ShardSelector {
    static func files(of plan: Plan, in shard: Shard) -> [String] {
        var countByFile: [String: Int] = [:]
        for mutant in plan.mutants {
            countByFile[mutant.file, default: 0] += 1
        }

        var load = Array(repeating: 0, count: shard.count)
        var assigned: [String] = []
        for (file, count) in countByFile.sorted(by: { $0.key < $1.key }) {
            let lightest = load.indices.min { load[$0] < load[$1] || (load[$0] == load[$1] && $0 < $1) } ?? 0
            load[lightest] += count
            if lightest == shard.index - 1 {
                assigned.append(file)
            }
        }
        return assigned
    }

    static func mutants(of plan: Plan, in shard: Shard) -> [Plan.Mutant] {
        let files = Set(files(of: plan, in: shard))
        return plan.mutants.filter { files.contains($0.file) }
    }
}
