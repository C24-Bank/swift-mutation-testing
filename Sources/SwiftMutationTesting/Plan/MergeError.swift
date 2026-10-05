import Foundation

enum MergeError: Error, Equatable, LocalizedError {
    case unreadableResult(path: String)
    case noIdentity(path: String)
    case differentPlan(path: String)
    case duplicate(fingerprint: String, paths: [String])
    case missing(count: Int, sample: [String])
    case unknownStatus(path: String, status: String)

    var errorDescription: String? {
        switch self {
        case .unreadableResult(let path):
            return "'\(path)' could not be read as a swift-mutation-testing JSON report"

        case .noIdentity(let path):
            return "'\(path)' names no plan (no config.planSha256); it was written by a version without plans"

        case .differentPlan(let path):
            return "'\(path)' comes from a different plan; every result of a merge must run the same plan"

        case .duplicate(let fingerprint, let paths):
            return "mutant \(fingerprint) has a verdict in more than one result: \(paths.joined(separator: ", "))"

        case .missing(let count, let sample):
            let list = sample.map { "  - \($0)" }.joined(separator: "\n")
            let more = count > sample.count ? "\n  … and \(count - sample.count) more" : ""
            let noun = count == 1 ? "mutant has" : "mutants have"
            return "\(count) \(noun) no verdict in any result, so no score can be given:\n\(list)\(more)\n"
                + "Run the missing shards, then merge again"

        case .unknownStatus(let path, let status):
            return "'\(path)' holds a status this version does not know: '\(status)'"
        }
    }
}
