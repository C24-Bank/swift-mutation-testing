import Foundation

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

    var exampleFile: String {
        switch self {
        case .json: "mutation-report.json"
        case .html: "mutation-report.html"
        case .sonar: "sonar-mutation-report.json"
        case .sarif: "mutation-report.sarif"
        case .markdown: "mutation-summary.md"
        }
    }

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
