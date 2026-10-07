import Foundation

/// Every report file a run can write, and how each is asked for: its command-line flag, its key in
/// `.swift-mutation-testing.yml`, its line in the help and in the file `init` writes. Adding a format is a case
/// here and its reporter in `ReportWriter`.
enum ReportFormat: String, CaseIterable, Sendable {
    case json
    case html
    case sonar
    case sarif
    case markdown

    var flag: String {
        switch self {
        case .json: "--output"
        case .html: "--html-output"
        case .sonar: "--sonar-output"
        case .sarif: "--sarif-output"
        case .markdown: "--markdown-output"
        }
    }

    /// The configuration-file key, the flag without its dashes.
    var fileKey: String {
        String(flag.dropFirst(2))
    }

    var label: String {
        switch self {
        case .json: "JSON"
        case .html: "HTML"
        case .sonar: "Sonar"
        case .sarif: "SARIF"
        case .markdown: "Markdown"
        }
    }

    /// The file `init` suggests writing it to.
    var exampleFile: String {
        switch self {
        case .json: "mutation-report.json"
        case .html: "mutation-report.html"
        case .sonar: "sonar-mutation-report.json"
        case .sarif: "mutation-report.sarif"
        case .markdown: "mutation-summary.md"
        }
    }

    /// The flag's line in the help, the description in the help's column.
    var helpLine: String {
        let usage: (argument: String, description: String) =
            switch self {
            case .json: ("<json-path>", "Write mutation report JSON to path")
            case .html: ("<html-path>", "Write HTML report to path")
            case .sonar: ("<json-path>", "Write a SonarQube generic issue import report to path")
            case .sarif: ("<sarif-path>", "Write a SARIF 2.1.0 report of undetected mutants to path")
            case .markdown: ("<md-path>", "Write a Markdown summary, for CI job summaries, to path")
            }
        return "\(flag) \(usage.argument)".padding(toLength: 30, withPad: " ", startingAt: 0) + usage.description
    }

    static func named(flag: String) -> ReportFormat? {
        allCases.first { $0.flag == flag }
    }
}
