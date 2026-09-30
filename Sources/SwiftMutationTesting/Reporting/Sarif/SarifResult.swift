struct SarifResult: Sendable, Encodable {
    let ruleId: String
    let ruleIndex: Int
    let level: String
    let message: SarifMessage
    let locations: [SarifLocation]
    let partialFingerprints: [String: String]
    let properties: SarifResultProperties
}
