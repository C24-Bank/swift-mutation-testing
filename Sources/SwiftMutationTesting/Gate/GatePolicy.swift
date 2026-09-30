struct GatePolicy: Sendable, Equatable {
    var minScore: Double?
    var maxScoreDrop: Double?
    var maxNewSurvivors: Int?

    var isEmpty: Bool {
        minScore == nil && maxScoreDrop == nil && maxNewSurvivors == nil
    }
}
