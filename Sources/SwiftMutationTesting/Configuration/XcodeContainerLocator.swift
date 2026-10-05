import Foundation

/// Decides which workspace or project a run builds, the same way for `init` and for every run.
///
/// An explicit `--workspace` or `--project` is checked and taken. Without one, the root decides: a single
/// `.xcworkspace` is the container, else a single `.xcodeproj`; more than one candidate is an error that
/// lists them, never a choice by directory order. A workspace whose projects lie outside the root is an
/// error too, since the sandbox only holds the root.
enum XcodeContainerLocator {
    struct Candidates: Sendable, Equatable {
        let workspaces: [String]
        let projects: [String]
    }

    static func locate(in root: URL, workspace: String?, project: String?) throws -> XcodeContainer? {
        if workspace != nil, project != nil {
            throw UsageError(message: "--workspace and --project cannot be used together; give one container")
        }

        if let workspace {
            let relative = try existing(workspace, extension: "xcworkspace", flag: "--workspace", in: root)
            try requireReferencesInside(root, workspace: relative)
            return .workspace(relative)
        }

        if let project {
            return .project(try existing(project, extension: "xcodeproj", flag: "--project", in: root))
        }

        let found = candidates(in: root)
        switch (found.workspaces.count, found.projects.count) {
        case (1, _):
            try requireReferencesInside(root, workspace: found.workspaces[0])
            return .workspace(found.workspaces[0])

        case (0, 1):
            return .project(found.projects[0])

        case (0, 0):
            return nil

        default:
            let names = found.workspaces.count > 1 ? found.workspaces : found.projects
            let flag = found.workspaces.count > 1 ? "--workspace" : "--project"
            throw UsageError(
                message: "found \(list(names)) at the project root; pass \(flag) (or the `\(flag.dropFirst(2))` key)"
                    + " to choose one"
            )
        }
    }

    /// The workspaces and projects at the root, in name order.
    static func candidates(in root: URL) -> Candidates {
        let names = ((try? FileManager.default.contentsOfDirectory(atPath: root.path)) ?? []).sorted()
        return Candidates(
            workspaces: names.filter { $0.hasSuffix(".xcworkspace") },
            projects: names.filter { $0.hasSuffix(".xcodeproj") }
        )
    }

    /// The projects a workspace references, as paths relative to the root; `self:` references (a project's
    /// own embedded workspace) are not projects.
    static func projects(referencedBy workspace: String, in root: URL) -> [String] {
        references(of: workspace, in: root)
            .filter { $0.hasSuffix(".xcodeproj") }
            .map { relative($0, to: root) ?? $0 }
    }

    // MARK: - Private

    private static func existing(_ path: String, extension ext: String, flag: String, in root: URL) throws -> String {
        let url = path.hasPrefix("/") ? URL(fileURLWithPath: path) : root.appendingPathComponent(path)
        var isDirectory: ObjCBool = false
        guard url.pathExtension == ext, FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory),
            isDirectory.boolValue
        else {
            throw UsageError(message: "\(flag) '\(path)' is not a .\(ext) under \(root.path)")
        }
        guard let relative = relative(url.path, to: root) else {
            throw UsageError(message: "\(flag) '\(path)' is outside the project root \(root.path)")
        }
        return relative
    }

    private static func requireReferencesInside(_ root: URL, workspace: String) throws {
        let outside = references(of: workspace, in: root).filter { relative($0, to: root) == nil }
        guard outside.isEmpty else {
            throw UsageError(
                message: "\(workspace) references \(list(outside)) outside the project root; the sandbox only holds "
                    + "the root, so run from a directory that contains every project of the workspace"
            )
        }
    }

    /// Absolute paths of the workspace's file references, groups resolved.
    private static func references(of workspace: String, in root: URL) -> [String] {
        let workspaceURL = root.appendingPathComponent(workspace)
        let contents = workspaceURL.appendingPathComponent("contents.xcworkspacedata")
        guard let parser = XMLParser(contentsOf: contents) else { return [] }
        let collector = ReferenceCollector(container: workspaceURL.deletingLastPathComponent())
        parser.delegate = collector
        parser.parse()
        return collector.references
    }

    private static func relative(_ path: String, to root: URL) -> String? {
        let base = root.standardizedFileURL.path
        let target = URL(fileURLWithPath: path).standardizedFileURL.path
        guard target.hasPrefix(base + "/") else { return nil }
        return String(target.dropFirst(base.count + 1))
    }

    private static func list(_ names: [String]) -> String {
        names.count <= 1
            ? names.joined()
            : names.dropLast().joined(separator: ", ") + " and " + (names.last ?? "")
    }

    private final class ReferenceCollector: NSObject, XMLParserDelegate {
        private let container: URL
        private var groups: [URL] = []
        private(set) var references: [String] = []

        init(container: URL) {
            self.container = container
        }

        func parser(
            _ parser: XMLParser, didStartElement element: String, namespaceURI: String?, qualifiedName: String?,
            attributes: [String: String] = [:]
        ) {
            guard element == "Group" || element == "FileRef" else { return }
            let base = groups.last ?? container
            let location = attributes["location"].flatMap { resolve($0, base: base) }

            if element == "Group" {
                groups.append(location ?? base)
            } else if let location {
                references.append(location.path)
            }
        }

        func parser(
            _ parser: XMLParser, didEndElement element: String, namespaceURI: String?, qualifiedName: String?
        ) {
            if element == "Group", !groups.isEmpty {
                groups.removeLast()
            }
        }

        private func resolve(_ location: String, base: URL) -> URL? {
            guard let colon = location.firstIndex(of: ":") else { return nil }
            let kind = location[..<colon]
            let path = String(location[location.index(after: colon)...])
            switch kind {
            case "group": return path.isEmpty ? base : base.appendingPathComponent(path)
            case "container": return path.isEmpty ? container : container.appendingPathComponent(path)
            case "absolute": return URL(fileURLWithPath: path)
            default: return nil
            }
        }
    }
}
