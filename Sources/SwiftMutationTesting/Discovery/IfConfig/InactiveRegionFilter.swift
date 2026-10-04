import SwiftSyntax

struct InactiveRegionFilter: Sendable {
    func filter(_ mutationPoints: [MutationPoint], inactiveRanges: [Range<AbsolutePosition>]) -> [MutationPoint] {
        guard !inactiveRanges.isEmpty else { return mutationPoints }

        return mutationPoints.filter { point in
            let position = AbsolutePosition(utf8Offset: point.utf8Offset)
            return !inactiveRanges.contains { $0.contains(position) }
        }
    }
}
