struct GatePolicy: Sendable, Equatable {
    var minScore: Double?
    var maxScoreDrop: Double?
    var maxNewSurvivors: Int?
    var maxIntegrityWarnings: Int?

    var isEmpty: Bool {
        minScore == nil && maxScoreDrop == nil && maxNewSurvivors == nil && maxIntegrityWarnings == nil
    }
}
