struct TestOutputParser: Sendable {
    enum Result: Sendable {
        case killed(by: String)
        case crashed
        case unviable
    }

    func parse(_ output: String) -> Result {
        var hasTestOutput = false
        var crashed = false

        for line in output.components(separatedBy: "\n") {
            if let name = failingTest(in: line) {
                return .killed(by: name)
            }

            if line.contains("Fatal error") || line.contains("EXC_BAD_INSTRUCTION") {
                crashed = true
            }

            if line.contains("Test Suite")
                || line.contains("Test run started")
                || line.contains("Testing started")
                || line.contains("** TEST FAILED **")
                || line.contains("Executed")
                || line.contains("◇ Suite")
                || line.contains("Test run with")
            {
                hasTestOutput = true
            }
        }

        return crashed || hasTestOutput ? .crashed : .unviable
    }

    func failingTests(in output: String) -> [String] {
        var seen: Set<String> = []

        return output.components(separatedBy: "\n").compactMap { line in
            guard let name = failingTest(in: line), seen.insert(name).inserted else {
                return nil
            }
            return name
        }
    }

    func failingTest(in line: String) -> String? {
        if let name = extractXCTestFailure(from: line) {
            return name
        }

        if let name = extractSwiftTestingFailure(from: line) {
            return name
        }

        return nil
    }

    private func extractXCTestFailure(from line: String) -> String? {
        let prefix = "Test Case '-["
        let suffix = "]' failed"
        let line = line.drop(while: { $0 == " " || $0 == "\t" })

        guard line.hasPrefix(prefix), let end = line.range(of: suffix)?.lowerBound else { return nil }

        let inner = String(line[line.index(line.startIndex, offsetBy: prefix.count) ..< end])
        let parts = inner.split(separator: " ", maxSplits: 1)

        guard parts.count == 2 else { return nil }

        return "\(parts[0]).\(parts[1])"
    }

    private func extractSwiftTestingFailure(from line: String) -> String? {
        guard let marker = line.range(of: "Test ")?.upperBound else { return nil }
        guard let (name, remainder) = splitTestName(in: line[marker...]) else { return nil }

        return describesFailure(remainder) ? name : nil
    }

    private func splitTestName(in text: Substring) -> (name: String, remainder: Substring)? {
        if text.hasPrefix("\"") {
            let afterQuote = text.dropFirst()

            guard let close = afterQuote.firstIndex(of: "\"") else { return nil }

            return (String(afterQuote[..<close]), afterQuote[afterQuote.index(after: close)...])
        }

        let end = text.firstIndex(of: " ") ?? text.endIndex
        let candidate = text[..<end]

        guard candidate.contains("("), candidate.hasSuffix(")") else { return nil }

        return (String(candidate), text[end...])
    }

    private func describesFailure(_ remainder: Substring) -> Bool {
        guard !remainder.contains("recorded a known issue") else { return false }

        return remainder.contains("recorded an issue") || remainder.contains(" failed")
    }
}
