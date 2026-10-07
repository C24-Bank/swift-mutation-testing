import SwiftSyntax

/// A part of the source where some mutations must not be made: a suppressed declaration, an inactive `#if`
/// clause, a loop body where a mutation could hang the tests.
protocol MutationExclusion: Sendable {
    /// The ranges of `syntax` the exclusion covers.
    func ranges(in syntax: SourceFileSyntax) -> [Range<AbsolutePosition>]

    /// Whether a mutation inside those ranges is left out; every one is, unless the exclusion narrows it.
    func applies(to point: MutationPoint) -> Bool
}

extension MutationExclusion {
    func applies(to point: MutationPoint) -> Bool {
        true
    }

    func filter(_ mutationPoints: [MutationPoint], excluding ranges: [Range<AbsolutePosition>]) -> [MutationPoint] {
        guard !ranges.isEmpty else { return mutationPoints }

        return mutationPoints.filter { point in
            guard applies(to: point) else { return true }
            let position = AbsolutePosition(utf8Offset: point.utf8Offset)
            return !ranges.contains { $0.contains(position) }
        }
    }

    func filter(_ mutationPoints: [MutationPoint], in syntax: SourceFileSyntax) -> [MutationPoint] {
        filter(mutationPoints, excluding: ranges(in: syntax))
    }
}
