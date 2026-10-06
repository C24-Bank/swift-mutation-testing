import Foundation

enum FileDiscoveryError: Error, Equatable, Sendable, LocalizedError {
    case sourcesPathNotFound(String)
    case sourcesPathNotSwift(String)
    case noMutants(sourcesPath: String)

    var errorDescription: String? {
        switch self {
        case .sourcesPathNotFound(let path):
            return "--sources-path '\(path)' does not exist"

        case .sourcesPathNotSwift(let path):
            return "--sources-path '\(path)' is neither a directory nor a .swift file"

        case .noMutants(let path):
            return "no mutants found under '\(path)', so nothing was measured and no score is given; "
                + "check --sources-path, --exclude and the operators"
        }
    }
}
