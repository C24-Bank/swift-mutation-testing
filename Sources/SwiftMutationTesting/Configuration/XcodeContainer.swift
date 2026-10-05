/// The workspace or project `xcodebuild` is given, as a path relative to the project root — and so to the
/// sandbox, where every build runs from the root.
enum XcodeContainer: Sendable, Equatable {
    case workspace(String)
    case project(String)

    var path: String {
        switch self {
        case .workspace(let path), .project(let path): path
        }
    }

    /// `-workspace <path>` or `-project <path>`.
    var arguments: [String] {
        switch self {
        case .workspace(let path): ["-workspace", path]
        case .project(let path): ["-project", path]
        }
    }

    /// The configuration key and command-line flag that name this kind of container.
    var key: String {
        switch self {
        case .workspace: "workspace"
        case .project: "project"
        }
    }
}
