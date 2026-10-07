/// Writes every report file the configuration asks for, in `ReportFormat` order.
struct ReportWriter: Sendable {
    let configuration: RunnerConfiguration

    func write(_ summary: RunnerSummary, gate: GateResult? = nil, identity: RunIdentity? = nil) {
        let requested = ReportFormat.allCases.compactMap { format in
            configuration.reporting.outputs[format].map { (format, $0) }
        }
        guard !requested.isEmpty else { return }
        StandardOutput.write("")

        for (format, path) in requested {
            do {
                try write(format, to: path, summary: summary, gate: gate, identity: identity)
                StandardOutput.write("  ✓ \(format.label) report: \(path)")
            } catch {
                StandardError.write(
                    "Warning: could not write \(format.label) report to '\(path)': \(error.localizedDescription)"
                )
            }
        }
    }

    // MARK: - Private

    private func write(
        _ format: ReportFormat, to path: String, summary: RunnerSummary, gate: GateResult?, identity: RunIdentity?
    ) throws {
        let root = configuration.projectPath
        switch format {
        case .json:
            try JsonReporter(outputPath: path, projectRoot: root).report(summary, identity: identity)
        case .html:
            try HtmlReporter(outputPath: path, projectRoot: root).report(summary)
        case .sonar:
            try SonarReporter(outputPath: path, projectRoot: root).report(summary)
        case .sarif:
            try SarifReporter(outputPath: path, projectRoot: root).report(summary)
        case .markdown:
            try MarkdownReporter(outputPath: path, projectRoot: root).report(summary, gate: gate)
        }
    }
}
