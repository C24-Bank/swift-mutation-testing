struct MutationReportPayload: Sendable, Codable {
    let schemaVersion: String
    let thresholds: MutationReportThresholds
    let projectRoot: String
    let files: [String: MutationReportFile]
    /// The schema's free-form configuration object; this tool puts the run's identity there.
    let config: MutationReportConfig?
}

struct MutationReportConfig: Sendable, Codable, Equatable {
    let toolVersion: String
    let planSha256: String
    let shard: String?
}
