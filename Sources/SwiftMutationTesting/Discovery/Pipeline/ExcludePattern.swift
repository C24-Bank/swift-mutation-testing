import Foundation

/// How an `--exclude` pattern matches a file.
///
/// A pattern with a glob metacharacter — `*`, `?` or `[` — is a glob, matched with `fnmatch(3)` without
/// `FNM_PATHNAME`, so `*` and `**` both cross directories: `**/Generated/**` matches every file under any
/// `Generated` directory, `Sources/Generated/**` the files under that one, `*.pb.swift` every such file. It
/// is tried against the path relative to the project root, that path with a leading `/` (so `**/X/**` also
/// matches `X` at the root), and the absolute path. A pattern without one is a fragment of the path, as it
/// has always been: `/Generated/` keeps matching what it matched.
enum ExcludePattern {
    static func matches(_ pattern: String, path: String, projectPath: String) -> Bool {
        guard isGlob(pattern) else {
            return path.contains(pattern)
        }

        let relative = ProjectRelativePath.make(for: path, in: projectPath)
        return [relative, "/" + relative, path].contains { candidate in glob(pattern, matches: candidate) }
    }

    /// `fnmatch(3)` with the C strings made explicitly: Swift 6.3 cannot infer the implicit `String` to
    /// pointer conversion inside a closure passed to `contains`.
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
