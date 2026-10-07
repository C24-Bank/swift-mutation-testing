/// Writes every report file the configuration asks for; adding a format is one entry in `reports`.
struct ReportWriter: Sendable {
    let configuration: RunnerConfiguration

    private struct Report {
        let label: String
        let path: String?
        let write: (String) throws -> Void
    }

    func write(_ summary: RunnerSummary, gate: GateResult? = nil, identity: RunIdentity? = nil) {
        let requested = reports(summary, gate: gate, identity: identity).compactMap { report in
            report.path.map { (report, $0) }
        }
        guard !requested.isEmpty else { return }
        StandardOutput.write("")

        for (report, path) in requested {
            do {
                try report.write(path)
                StandardOutput.write("  ✓ \(report.label) report: \(path)")
            } catch {
                StandardError.write(
                    "Warning: could not write \(report.label) report to '\(path)': \(error.localizedDescription)"
                )
            }
        }
    }

    // MARK: - Private

    private func reports(_ summary: RunnerSummary, gate: GateResult?, identity: RunIdentity?) -> [Report] {
        let reporting = configuration.reporting
        let root = configuration.projectPath
        return [
            Report(label: "JSON", path: reporting.output) {
                try JsonReporter(outputPath: $0, projectRoot: root).report(summary, identity: identity)
            },
            Report(label: "HTML", path: reporting.htmlOutput) {
                try HtmlReporter(outputPath: $0, projectRoot: root).report(summary)
            },
            Report(label: "Sonar", path: reporting.sonarOutput) {
                try SonarReporter(outputPath: $0, projectRoot: root).report(summary)
            },
            Report(label: "SARIF", path: reporting.sarifOutput) {
                try SarifReporter(outputPath: $0, projectRoot: root).report(summary)
            },
            Report(label: "Markdown", path: reporting.markdownOutput) {
                try MarkdownReporter(outputPath: $0, projectRoot: root).report(summary, gate: gate)
            },
        ]
    }
}
