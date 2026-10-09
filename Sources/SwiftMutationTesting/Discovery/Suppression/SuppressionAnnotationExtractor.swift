import SwiftSyntax

struct SuppressionAnnotationExtractor: Sendable {
    static let coverageExclusionStart = "// START-COVERAGE-EXCLUSION"
    static let coverageExclusionEnd = "// END-COVERAGE-EXCLUSION"

    /// Also suppresses what the coverage report leaves out: `#if` blocks and the code between the
    /// coverage-exclusion marker comments.
    var excludeCoverageBlocks = false

    func extractSuppressedRanges(from syntax: SourceFileSyntax) -> [Range<AbsolutePosition>] {
        let visitor = SuppressionVisitor(suppressesConditionalCompilation: excludeCoverageBlocks)
        visitor.walk(syntax)
        guard excludeCoverageBlocks else { return visitor.suppressedRanges }
        return visitor.suppressedRanges + markerRanges(in: syntax)
    }

    private func markerRanges(in syntax: SourceFileSyntax) -> [Range<AbsolutePosition>] {
        let text = Array(syntax.description.utf8)
        let start = Array(Self.coverageExclusionStart.utf8)
        let end = Array(Self.coverageExclusionEnd.utf8)
        var ranges: [Range<AbsolutePosition>] = []
        var index = 0

        while let startOffset = offset(of: start, in: text, from: index) {
            let endOffset = offset(of: end, in: text, from: startOffset + start.count) ?? text.count
            ranges.append(AbsolutePosition(utf8Offset: startOffset) ..< AbsolutePosition(utf8Offset: endOffset))
            index = endOffset + 1
        }

        return ranges
    }

    private func offset(of needle: [UInt8], in haystack: [UInt8], from start: Int) -> Int? {
        guard needle.isEmpty == false, start <= haystack.count - needle.count else { return nil }
        var index = start
        while index <= haystack.count - needle.count {
            if haystack[index] == needle[0], Array(haystack[index ..< index + needle.count]) == needle {
                return index
            }
            index += 1
        }
        return nil
    }
}
