struct MutationReportMutant: Sendable, Codable {
    let id: String
    let mutatorName: String
    let originalText: String
    let replacement: String
    let location: MutationReportLocation
    let status: String
    let statusReason: String?
    let description: String
    let killedBy: [String]?
    let duration: Int?
    let fingerprint: String
    /// Whether the mutated code ran, when it was measured; outside the schema, like `fingerprint`.
    let activated: Bool?
}
