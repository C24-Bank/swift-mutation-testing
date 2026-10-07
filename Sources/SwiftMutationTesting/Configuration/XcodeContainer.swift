enum XcodeContainer: Sendable, Equatable {
    case workspace(String)
    case project(String)

    var path: String {
        switch self {
        case .workspace(let path), .project(let path): path
        }
    }

    var arguments: [String] {
        switch self {
        case .workspace(let path): ["-workspace", path]
        case .project(let path): ["-project", path]
        }
    }

    var key: String {
        switch self {
        case .workspace: "workspace"
        case .project: "project"
        }
    }
}
