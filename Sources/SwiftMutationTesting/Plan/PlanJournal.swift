import Foundation

/// The verdicts of one run of a plan — or of one shard of it — appended the moment each is known.
///
/// `run --plan` reads the journal of its plan and shard, runs only the mutants it has no verdict for, and
/// removes the journal when the run finishes. So the journal only ever holds what an interrupted run had
/// reached, and it is kept even under `--no-cache`: it is not a cache of verdicts across code changes but
/// the progress of one plan, whose files the plan's hashes pin.
struct PlanJournal: Sendable {
    struct Entry: Sendable, Codable, Equatable {
        let fingerprint: String
        let status: ExecutionStatus
        let killerTestFile: String?
        let activated: Bool?
        let duration: Double
    }

    let path: String
    private let fingerprintByKey: [MutantCacheKey: String]

    init(path: String, mutants: [MutantDescriptor]) {
        self.path = path
        fingerprintByKey = Dictionary(
            mutants.map { (MutantCacheKey.make(for: $0), $0.fingerprint) }, uniquingKeysWith: { first, _ in first }
        )
    }

    static func path(projectPath: String, planSha256: String, shard: Shard?) -> String {
        let name = shard.map { "\(planSha256)-\($0.index)-of-\($0.count)" } ?? planSha256
        return URL(fileURLWithPath: projectPath)
            .appendingPathComponent(CacheStore.directoryName)
            .appendingPathComponent("plans")
            .appendingPathComponent("\(name).jsonl").path
    }

    func record(
        status: ExecutionStatus, for key: MutantCacheKey, killerTestFile: String?, activated: Bool?, duration: Double
    ) {
        guard let fingerprint = fingerprintByKey[key] else { return }
        let entry = Entry(
            fingerprint: fingerprint, status: status, killerTestFile: killerTestFile, activated: activated,
            duration: duration
        )
        JSONLines.append(entry, to: path)
    }

    /// The entries of the journal at `path`, the last one winning for a fingerprint; a line cut short by an
    /// interruption is skipped.
    static func entries(at path: String) -> [String: Entry] {
        Dictionary(
            JSONLines.read(Entry.self, from: path).map { ($0.fingerprint, $0) }, uniquingKeysWith: { _, last in last }
        )
    }

    static func remove(at path: String) {
        try? FileManager.default.removeItem(atPath: path)
    }
}
