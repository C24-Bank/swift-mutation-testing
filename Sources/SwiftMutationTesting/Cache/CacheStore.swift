import Foundation

actor CacheStore {

    init(storePath: String, noCache: Bool = false, planJournal: PlanJournal? = nil) {
        self.storePath = storePath
        self.noCache = noCache
        self.planJournal = planJournal
        self.entries = [:]
        self.killerTestFiles = [:]
        self.activations = [:]
    }

    static let directoryName = ".swift-mutation-testing-cache"
    static let formatVersion = 2
    static let journalName = "journal.jsonl"

    private let storePath: String
    private let noCache: Bool
    private let planJournal: PlanJournal?
    private var entries: [MutantCacheKey: ExecutionStatus]
    private var killerTestFiles: [MutantCacheKey: String]
    private var activations: [MutantCacheKey: Bool]

    private var metadataPath: String {
        let url = URL(fileURLWithPath: storePath)
        return url.deletingLastPathComponent().appendingPathComponent("metadata.json").path
    }

    /// One verdict per line, appended as soon as it is known. A run that ends before `persist()` — a
    /// `Ctrl+C`, a crash, a lost machine — leaves its verdicts here, and the next `load()` replays them, so
    /// the run continues where it stopped. `persist()` folds the journal into the results file and removes it.
    private var journalPath: String {
        let url = URL(fileURLWithPath: storePath)
        return url.deletingLastPathComponent().appendingPathComponent(Self.journalName).path
    }

    private struct CacheEntry: Codable {
        let key: MutantCacheKey
        let status: ExecutionStatus
        let killerTestFile: String?
        let activated: Bool?
    }

    struct CacheMetadata: Codable, Sendable {

        init(testFileHashes: [String: String], formatVersion: Int = CacheStore.formatVersion) {
            self.formatVersion = formatVersion
            self.testFileHashes = testFileHashes
        }

        let formatVersion: Int
        let testFileHashes: [String: String]
    }

    func result(for key: MutantCacheKey) -> ExecutionStatus? {
        noCache ? nil : entries[key]
    }

    func killerTestFile(for key: MutantCacheKey) -> String? {
        noCache ? nil : killerTestFiles[key]
    }

    func activated(for key: MutantCacheKey) -> Bool? {
        noCache ? nil : activations[key]
    }

    func store(
        status: ExecutionStatus,
        for key: MutantCacheKey,
        killerTestFile: String? = nil,
        activated: Bool? = nil,
        duration: Double = 0
    ) {
        planJournal?.record(
            status: status, for: key, killerTestFile: killerTestFile, activated: activated, duration: duration
        )

        guard !noCache else { return }
        guard status != .timeout else { return }

        entries[key] = status
        if let killerTestFile {
            killerTestFiles[key] = killerTestFile
        }
        if let activated {
            activations[key] = activated
        }

        journal(CacheEntry(key: key, status: status, killerTestFile: killerTestFile, activated: activated))
    }

    func load() throws {
        guard !noCache else { return }
        guard FileManager.default.fileExists(atPath: storePath) else {
            apply(journaledEntries())
            return
        }

        if FileManager.default.fileExists(atPath: metadataPath), try loadMetadata() == nil {
            discardUnreadable()
            return
        }

        let data = try Data(contentsOf: URL(fileURLWithPath: storePath))
        guard let loaded = try? JSONDecoder().decode([CacheEntry].self, from: data) else {
            discardUnreadable()
            return
        }
        entries = [:]
        killerTestFiles = [:]
        activations = [:]
        apply(loaded + journaledEntries())
    }

    private func apply(_ loaded: [CacheEntry]) {
        for entry in loaded {
            entries[entry.key] = entry.status
            if let file = entry.killerTestFile {
                killerTestFiles[entry.key] = file
            }
            if let activated = entry.activated {
                activations[entry.key] = activated
            }
        }
    }

    private func journaledEntries() -> [CacheEntry] {
        guard let data = FileManager.default.contents(atPath: journalPath) else { return [] }

        return data.split(separator: UInt8(ascii: "\n")).compactMap { line in
            try? JSONDecoder().decode(CacheEntry.self, from: line)
        }
    }

    private func journal(_ entry: CacheEntry) {
        guard var line = try? JSONEncoder().encode(entry) else { return }
        line.append(UInt8(ascii: "\n"))

        let url = URL(fileURLWithPath: journalPath)
        try? FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        if let handle = try? FileHandle(forWritingTo: url) {
            defer { try? handle.close() }
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: line)
        } else {
            try? line.write(to: url)
        }
    }

    func persist() throws {
        guard !noCache else { return }

        let cacheEntries = entries.map {
            CacheEntry(
                key: $0.key, status: $0.value, killerTestFile: killerTestFiles[$0.key], activated: activations[$0.key]
            )
        }
        let data = try JSONEncoder().encode(cacheEntries)
        let url = URL(fileURLWithPath: storePath)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: url, options: .atomic)
        try? FileManager.default.removeItem(atPath: journalPath)
    }

    func loadMetadata() throws -> CacheMetadata? {
        guard !noCache else { return nil }

        let url = URL(fileURLWithPath: metadataPath)
        guard FileManager.default.fileExists(atPath: metadataPath) else { return nil }
        let data = try Data(contentsOf: url)
        guard
            let metadata = try? JSONDecoder().decode(CacheMetadata.self, from: data),
            metadata.formatVersion == Self.formatVersion
        else { return nil }
        return metadata
    }

    func persistMetadata(_ metadata: CacheMetadata) throws {
        guard !noCache else { return }

        let data = try JSONEncoder().encode(metadata)
        let url = URL(fileURLWithPath: metadataPath)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: url, options: .atomic)
    }

    func invalidate(diff: TestFileDiff) {
        guard diff.hasChanges else { return }

        let changedFiles = diff.modified.union(diff.removed)

        for (key, status) in entries {
            switch status {
            case .unviable:
                continue

            case .killed:
                guard let file = killerTestFiles[key] else {
                    forget(key)
                    continue
                }

                if changedFiles.contains(file) {
                    forget(key)
                }

            case .survived, .noCoverage, .timeout, .killedByCrash:
                forget(key)
            }
        }
    }

    private func forget(_ key: MutantCacheKey) {
        entries.removeValue(forKey: key)
        killerTestFiles.removeValue(forKey: key)
        activations.removeValue(forKey: key)
    }

    func changedTestFiles(current: [String: String]) throws -> TestFileDiff {
        guard let stored = try loadMetadata() else {
            return TestFileDiff(
                added: Set(current.keys),
                modified: [],
                removed: []
            )
        }

        let storedKeys = Set(stored.testFileHashes.keys)
        let currentKeys = Set(current.keys)

        let added = currentKeys.subtracting(storedKeys)
        let removed = storedKeys.subtracting(currentKeys)

        var modified: Set<String> = []
        for key in storedKeys.intersection(currentKeys) where stored.testFileHashes[key] != current[key] {
            modified.insert(key)
        }

        return TestFileDiff(added: added, modified: modified, removed: removed)
    }

    // MARK: - Private

    private func discardUnreadable() {
        entries = [:]
        killerTestFiles = [:]
        let directory = URL(fileURLWithPath: storePath).deletingLastPathComponent().path
        fputs(
            "Warning: ignoring the cache at '\(directory)', which this version cannot read; "
                + "every mutant will be tested again.\n",
            stderr
        )
    }
}
