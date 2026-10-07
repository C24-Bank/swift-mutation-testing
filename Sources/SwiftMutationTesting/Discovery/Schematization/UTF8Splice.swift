/// Byte-range edits on a string's UTF-8 form, the unit SwiftSyntax offsets count in.
///
/// Each answers `nil` when the range does not lie inside the string or the edit would leave bytes that are
/// not UTF-8 — a range cutting through a character — and the caller decides what that means.
enum UTF8Splice {
    static func substring(of content: String, from start: Int, to end: Int) -> String? {
        let bytes = Array(content.utf8)
        guard start >= 0, start <= end, end <= bytes.count else { return nil }
        return String(bytes: bytes[start ..< end], encoding: .utf8)
    }

    static func replacing(from start: Int, to end: Int, in content: String, with replacement: String) -> String? {
        var bytes = Array(content.utf8)
        guard start >= 0, start <= end, end <= bytes.count else { return nil }
        bytes.replaceSubrange(start ..< end, with: replacement.utf8)
        return String(bytes: bytes, encoding: .utf8)
    }

    static func inserting(_ text: String, at offset: Int, in content: String) -> String? {
        replacing(from: offset, to: offset, in: content, with: text)
    }
}
