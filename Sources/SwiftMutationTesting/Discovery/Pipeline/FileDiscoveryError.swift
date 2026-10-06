import Foundation

enum FileDiscoveryError: Error, Equatable, Sendable, LocalizedError {
    case sourcesPathNotFound(String)
    case sourcesPathNotSwift(String)

    var errorDescription: String? {
        switch self {
        case .sourcesPathNotFound(let path):
            return "--sources-path '\(path)' does not exist"

        case .sourcesPathNotSwift(let path):
            return "--sources-path '\(path)' is neither a directory nor a .swift file"

        }
    }
}
