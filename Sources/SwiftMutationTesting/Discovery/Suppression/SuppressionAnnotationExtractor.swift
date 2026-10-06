import SwiftSyntax

struct SuppressionAnnotationExtractor: Sendable {
    func extractSuppressedRanges(from syntax: SourceFileSyntax) -> [Range<AbsolutePosition>] {
        let visitor = SuppressionVisitor(converter: SourceLocationConverter(fileName: "", tree: syntax))
        visitor.walk(syntax)
        return visitor.suppressedRanges
    }
}
