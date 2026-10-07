import Foundation

enum ExcludePattern {
    static func matches(_ pattern: String, path: String, projectPath: String) -> Bool {
        guard isGlob(pattern) else {
            return path.contains(pattern)
        }

        let relative = ProjectRelativePath.make(for: path, in: projectPath)
        return [relative, "/" + relative, path].contains { candidate in glob(pattern, matches: candidate) }
    }

    private static func glob(_ pattern: String, matches candidate: String) -> Bool {
        pattern.withCString { cPattern in
            candidate.withCString { cCandidate in
                fnmatch(cPattern, cCandidate, 0) == 0
            }
        }
    }

    static func isGlob(_ pattern: String) -> Bool {
        pattern.contains { $0 == "*" || $0 == "?" || $0 == "[" }
    }
}
