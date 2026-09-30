import Foundation

enum GateError: Error, Equatable, LocalizedError {
    case baselineNotFound(path: String)
    case unreadableBaseline(path: String)
    case unsupportedBaselineVersion(path: String, version: Int)
    case scopeMismatch(path: String, differences: [String])

    var errorDescription: String? {
        switch self {
        case .baselineNotFound(let path):
            return "baseline '\(path)' does not exist; write one with --write-baseline"

        case .unreadableBaseline(let path):
            return "baseline '\(path)' could not be read as a swift-mutation-testing baseline"

        case .unsupportedBaselineVersion(let path, let version):
            return "baseline '\(path)' has format version \(version), which this version cannot read; "
                + "write it again with --write-baseline"

        case .scopeMismatch(let path, let differences):
            return "baseline '\(path)' was recorded with a different scope, so the runs cannot be compared:\n"
                + differences.map { "  - \($0)" }.joined(separator: "\n")
                + "\nRun with the baseline's scope, or write a new baseline with --write-baseline"
        }
    }
}
