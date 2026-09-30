struct GateResult: Sendable {
    let checks: [Check]
    let newUndetected: [ExecutionResult]
    let fixedCount: Int?

    var passed: Bool {
        checks.allSatisfy(\.passed)
    }

    enum Check: Sendable, Equatable {
        case minScore(score: Double, minimum: Double)
        case scoreDrop(drop: Double, maximum: Double)
        case newUndetected(count: Int, maximum: Int)

        var passed: Bool {
            switch self {
            case .minScore(let score, let minimum): score >= minimum
            case .scoreDrop(let drop, let maximum): drop <= maximum
            case .newUndetected(let count, let maximum): count <= maximum
            }
        }
    }
}
