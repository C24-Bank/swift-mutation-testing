struct SarifRule: Sendable, Encodable {
    let id: String
    let name: String
    let shortDescription: SarifMessage
    let fullDescription: SarifMessage
    let helpUri: String
    let defaultConfiguration: SarifConfiguration
}
