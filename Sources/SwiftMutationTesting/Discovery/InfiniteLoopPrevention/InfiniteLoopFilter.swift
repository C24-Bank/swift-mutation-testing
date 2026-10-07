import SwiftSyntax

struct InfiniteLoopFilter: MutationExclusion {

    private static let riskyOperators: Set<String> = [
        "ArithmeticOperatorReplacement",
        "RemoveSideEffects",
    ]

    private let extractor = InfiniteLoopBodyExtractor()

    func ranges(in syntax: SourceFileSyntax) -> [Range<AbsolutePosition>] {
        extractor.extractLoopBodyRanges(from: syntax)
    }

    func applies(to point: MutationPoint) -> Bool {
        Self.riskyOperators.contains(point.operatorIdentifier)
    }
}
