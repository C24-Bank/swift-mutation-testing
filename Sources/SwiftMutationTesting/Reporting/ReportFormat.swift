/// Every report file a run can write, and how each is asked for: its command-line flag and its key in
/// `.swift-mutation-testing.yml`. Adding a format is a case here and its reporter in `ReportWriter`.
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

    static func named(flag: String) -> ReportFormat? {
        allCases.first { $0.flag == flag }
    }
}
