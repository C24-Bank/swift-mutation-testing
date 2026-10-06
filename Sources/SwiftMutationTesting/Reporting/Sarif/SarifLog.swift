struct SarifLog: Sendable, Encodable {
    let schema: String
    let version: String
    let runs: [SarifRun]

    init(runs: [SarifRun]) {
        schema = "https://json.schemastore.org/sarif-2.1.0.json"
        version = "2.1.0"
        self.runs = runs
    }

    enum CodingKeys: String, CodingKey {
        case schema = "$schema"
        case version, runs
    }
}
