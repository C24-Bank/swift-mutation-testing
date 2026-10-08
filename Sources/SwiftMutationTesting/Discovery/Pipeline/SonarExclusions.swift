import Foundation

/// The files SonarQube leaves out of analysis or coverage, read from a `sonar-project.properties`.
///
/// Code Sonar does not expect to be tested is not worth mutating either, so the same glob patterns
/// (`sonar.exclusions` and `sonar.coverage.exclusions`) exclude files from discovery. Patterns are
/// relative to the Sonar project base directory, as Sonar resolves them.
struct SonarExclusions: Sendable {
    static let keys = ["sonar.exclusions", "sonar.coverage.exclusions"]

    let baseDirectory: String
    let patterns: [String]
    private let expressions: [NSRegularExpression]

    init(baseDirectory: String, patterns: [String]) {
        self.baseDirectory = Self.canonical(baseDirectory)
        self.patterns = patterns
        self.expressions = patterns.compactMap { try? NSRegularExpression(pattern: Self.regex(forGlob: $0)) }
    }

    static func load(propertiesPath: String) throws -> SonarExclusions {
        let content = try String(contentsOfFile: propertiesPath, encoding: .utf8)
        let properties = parse(properties: content)
        let fileDirectory = (propertiesPath as NSString).deletingLastPathComponent
        let base = properties["sonar.projectBaseDir"].map { (fileDirectory as NSString).appendingPathComponent($0) }
            ?? fileDirectory
        let patterns = keys.flatMap { key in
            (properties[key] ?? "")
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { $0.isEmpty == false }
        }
        return SonarExclusions(baseDirectory: base, patterns: patterns)
    }

    func excludes(path: String) -> Bool {
        let absolute = Self.canonical(path)
        guard absolute.hasPrefix(baseDirectory + "/") else { return false }
        let relative = String(absolute.dropFirst(baseDirectory.count + 1))
        let range = NSRange(relative.startIndex..., in: relative)
        return expressions.contains { $0.firstMatch(in: relative, range: range) != nil }
    }

    /// Java-style properties: `key=value` or `key: value`, `#`/`!` comments, `\` line continuations.
    static func parse(properties: String) -> [String: String] {
        var result: [String: String] = [:]
        var pending = ""

        for rawLine in properties.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if pending.isEmpty, line.hasPrefix("#") || line.hasPrefix("!") || line.isEmpty {
                continue
            }
            if line.hasSuffix("\\") {
                pending += String(line.dropLast()) + " "
                continue
            }
            let entry = pending + line
            pending = ""
            guard let separator = entry.firstIndex(where: { $0 == "=" || $0 == ":" }) else { continue }
            let key = entry[..<separator].trimmingCharacters(in: .whitespaces)
            let value = entry[entry.index(after: separator)...].trimmingCharacters(in: .whitespaces)
            result[key] = value
        }

        return result
    }

    /// Sonar globs: `**` any number of directories, `*` within one path segment, `?` one character.
    static func regex(forGlob glob: String) -> String {
        var pattern = "^"
        var index = glob.startIndex

        while index < glob.endIndex {
            let rest = glob[index...]
            if rest.hasPrefix("**/") {
                pattern += "(?:.*/)?"
                index = glob.index(index, offsetBy: 3)
            } else if rest.hasPrefix("**") {
                pattern += ".*"
                index = glob.index(index, offsetBy: 2)
            } else {
                let character = glob[index]
                switch character {
                case "*": pattern += "[^/]*"
                case "?": pattern += "[^/]"
                default: pattern += NSRegularExpression.escapedPattern(for: String(character))
                }
                index = glob.index(after: index)
            }
        }

        return pattern + "$"
    }

    private static func canonical(_ path: String) -> String {
        URL(fileURLWithPath: path).resolvingSymlinksInPath().standardizedFileURL.path
    }
}
