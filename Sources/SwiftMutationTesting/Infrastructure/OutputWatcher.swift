import Foundation

struct OutputWatcher {
    private let url: URL
    private let rule: OutputStopRule
    private var scanned: UInt64 = 0
    private var carry = ""

    init(url: URL, rule: OutputStopRule) {
        self.url = url
        self.rule = rule
    }

    mutating func sawMarker() -> Bool {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return false }
        defer { try? handle.close() }

        guard (try? handle.seek(toOffset: scanned)) != nil, let data = try? handle.readToEnd(), !data.isEmpty
        else { return false }

        scanned += UInt64(data.count)
        let text = carry + String(decoding: data, as: UTF8.self)

        if let lastNewline = text.lastIndex(of: "\n") {
            carry = String(text[text.index(after: lastNewline)...])
        } else {
            carry = text
        }

        return rule.matches(text)
    }
}
