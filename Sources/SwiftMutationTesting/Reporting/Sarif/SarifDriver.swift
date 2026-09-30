struct SarifDriver: Sendable, Encodable {
    let name: String
    let version: String
    let informationUri: String
    let rules: [SarifRule]
}
