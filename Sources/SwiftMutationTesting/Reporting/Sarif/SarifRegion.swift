struct SarifRegion: Sendable, Encodable {
    let startLine: Int
    let startColumn: Int
    let endColumn: Int
}
