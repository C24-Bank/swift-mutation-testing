struct SarifLog: Sendable, Encodable {
    let schema = "https://json.schemastore.org/sarif-2.1.0.json"
    let version = "2.1.0"
    let runs: [SarifRun]

    enum CodingKeys: String, CodingKey {
        case schema = "$schema"
        case version, runs
    }
}
