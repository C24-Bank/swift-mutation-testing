struct BaselineEntry: Sendable, Codable, Equatable {
    let fingerprint: String
    let file: String
    let line: Int
    let operatorIdentifier: String
    let original: String
    let replacement: String
    let status: String

    enum CodingKeys: String, CodingKey {
        case fingerprint, file, line, original, replacement, status
        case operatorIdentifier = "operator"
    }
}
