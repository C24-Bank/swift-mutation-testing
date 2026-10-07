import SwiftSyntax

struct InfiniteLoopFilter: MutationExclusion {
    var riskyOperators: Set<String> = OperatorRegistry.loopRiskyNames

    private let extractor = InfiniteLoopBodyExtractor()

    func ranges(in syntax: SourceFileSyntax) -> [Range<AbsolutePosition>] {
        extractor.extractLoopBodyRanges(from: syntax)
    }

    func applies(to point: MutationPoint) -> Bool {
        riskyOperators.contains(point.operatorIdentifier)
    }
}
