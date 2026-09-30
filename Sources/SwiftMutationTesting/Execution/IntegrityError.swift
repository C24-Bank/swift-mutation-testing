import Foundation

enum IntegrityError: Error, Equatable, LocalizedError {
    case mutantsNotApplied(ids: [String])
    case schemaNotApplied(path: String)
    case supportMissing(path: String)

    var errorDescription: String? {
        switch self {
        case .mutantsNotApplied(let ids):
            let listed = ids.prefix(10).joined(separator: ", ")
            let more = ids.count > 10 ? " and \(ids.count - 10) more" : ""
            let count = "\(ids.count) mutant\(ids.count == 1 ? " was" : "s were")"
            return "\(count) not applied to the sandbox: \(listed)\(more). "
                + "The run is stopped, since a verdict on a mutation that is not in the build says nothing"

        case .schemaNotApplied(let path):
            return "the sandbox copy of '\(path)' is identical to the original, "
                + "so none of its mutants is in the build. The run is stopped"

        case .supportMissing(let path):
            return "the sandbox copy of '\(path)' does not declare __swiftMutationTestingID, "
                + "so its schema could not compile. The run is stopped"
        }
    }
}
