enum OperatorTier: String, Sendable, CaseIterable, Comparable {
    case conservative
    case `default`
    case experimental

    static let usage = "--operator-tier must be 'conservative', 'default' or 'experimental'"

    static func < (lhs: OperatorTier, rhs: OperatorTier) -> Bool {
        lhs.rank < rhs.rank
    }

    private var rank: Int {
        switch self {
        case .conservative: 0
        case .default: 1
        case .experimental: 2
        }
    }
}
