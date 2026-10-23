import Foundation

/// A one-page Markdown summary that points at the easy wins: untested files and files whose tests miss the most.
struct SummaryReporter: Sendable {
    let outputPath: String
    let projectRoot: String
    var topCount = 20
    var spotsPerFile = 5

    private static let meanings: [String: String] = [
        "NegateConditional": "a condition can be wrong in both directions",
        "ConstantCondition": "one branch of a condition is never checked",
        "LogicalOperatorReplacement": "`&&` and `||` are interchangeable",
        "SwapTernary": "the two results of a `?:` are interchangeable",
        "ReturnValue": "the returned value is not asserted",
        "RemoveSideEffects": "the call is not checked to happen",
        "CollectionOperation": "which element is picked is not checked",
        "ConditionalBoundary": "the value at the edge is not tested",
        "RelationalOperatorReplacement": "a comparison is not pinned",
        "BooleanLiteralReplacement": "a literal `true`/`false` is not pinned",
        "ArithmeticOperatorReplacement": "a calculation is not pinned",
    ]

    func report(_ summary: RunnerSummary) throws {
        try render(summary).write(toFile: outputPath, atomically: true, encoding: .utf8)
    }

    func render(_ summary: RunnerSummary) -> String {
        var lines = ["# Mutation testing summary", ""]
        lines += overview(summary)
        lines += untestedFiles(summary)
        lines += filesWithMostSurvivors(summary)
        lines += byType(summary)
        return lines.joined(separator: "\n") + "\n"
    }

    private func overview(_ summary: RunnerSummary) -> [String] {
        let hours = summary.totalDuration / 3600
        return [
            "| Mutants | Caught | Survived | No tests | Timeouts | Not compilable | Score | Run time (this run) |",
            "| ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |",
            "| \(summary.results.count) | \(summary.killed.count) | \(summary.survived.count) "
                + "| \(summary.noCoverage.count) | \(summary.timeouts.count) | \(summary.unviable.count) "
                + "| \(summary.scoreText) | \(String(format: "%.1f", hours)) h |",
            "",
            "A survivor is a small bug the tool put into the code that no test noticed. "
                + "\"No tests\" means no test uses the file at all.",
            "",
        ]
    }

    private func untestedFiles(_ summary: RunnerSummary) -> [String] {
        let byFile = Dictionary(grouping: summary.noCoverage, by: { relative($0.descriptor.filePath) })
        guard !byFile.isEmpty else { return [] }

        var lines = [
            "## Files without any tests (\(byFile.count) files)",
            "",
            "No test uses these files, so none of their mutants can be caught. One test file covers many of them.",
            "",
            "| File | Mutants |",
            "| --- | ---: |",
        ]
        for (file, results) in byFile.sorted(by: { ($0.value.count, $1.key) > ($1.value.count, $0.key) }).prefix(topCount) {
            lines.append("| `\(file)` | \(results.count) |")
        }
        return lines + [""]
    }

    private func filesWithMostSurvivors(_ summary: RunnerSummary) -> [String] {
        let byFile = Dictionary(grouping: summary.results, by: { relative($0.descriptor.filePath) })
        let ranked = byFile
            .map { file, results in (file: file, results: results, survived: results.filter { $0.status == .survived }) }
            .filter { !$0.survived.isEmpty }
            .sorted { ($0.survived.count, $1.file) > ($1.survived.count, $0.file) }
        guard !ranked.isEmpty else { return [] }

        var lines = [
            "## Files with the most survivors (\(ranked.count) files)",
            "",
            "These files have tests, but the tests miss these changes. Each spot is a place where a bug would go unnoticed.",
            "",
            "| File | Survived | Score | Spots (line: change) |",
            "| --- | ---: | ---: | --- |",
        ]
        for entry in ranked.prefix(topCount) {
            let spots = entry.survived
                .sorted { $0.descriptor.line < $1.descriptor.line }
                .prefix(spotsPerFile)
                .map { "\($0.descriptor.line): \(escaped($0.descriptor.description))" }
                .joined(separator: "<br>")
            let more = entry.survived.count > spotsPerFile ? "<br>… \(entry.survived.count - spotsPerFile) more" : ""
            let score = RunnerSummary(results: entry.results, totalDuration: 0).scoreText
            lines.append("| `\(entry.file)` | \(entry.survived.count) | \(score) | \(spots)\(more) |")
        }
        return lines + [""]
    }

    private func byType(_ summary: RunnerSummary) -> [String] {
        let byOperator = Dictionary(grouping: summary.results, by: \.descriptor.operatorIdentifier)
        var lines = [
            "## By mutation type",
            "",
            "| Type | A survivor means | Mutants | Survived | Score |",
            "| --- | --- | ---: | ---: | ---: |",
        ]
        for (name, results) in byOperator.sorted(by: { $0.value.count > $1.value.count }) {
            let typeSummary = RunnerSummary(results: results, totalDuration: 0)
            lines.append(
                "| \(name) | \(escaped(Self.meanings[name] ?? "")) | \(results.count) "
                    + "| \(typeSummary.survived.count) | \(typeSummary.scoreText) |"
            )
        }
        return lines
    }

    private func relative(_ path: String) -> String {
        let root = projectRoot.hasSuffix("/") ? projectRoot : projectRoot + "/"
        return path.hasPrefix(root) ? String(path.dropFirst(root.count)) : path
    }

    private func escaped(_ text: String) -> String {
        let flattened = text.replacingOccurrences(of: "\n", with: " ").replacingOccurrences(of: "|", with: "\\|")
        return flattened.count > 80 ? String(flattened.prefix(77)) + "…" : flattened
    }
}
