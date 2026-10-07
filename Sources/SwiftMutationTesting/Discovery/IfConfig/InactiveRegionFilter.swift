import SwiftSyntax

struct InactiveRegionFilter: MutationExclusion {
    private let extractor = InactiveRegionExtractor()

    func ranges(in syntax: SourceFileSyntax) -> [Range<AbsolutePosition>] {
        extractor.extractInactiveRanges(from: syntax)
    }
}
