import Foundation

struct ChangedLines: Sendable {
    private let linesByFile: [String: Set<Int>]

    var files: Set<String> { Set(linesByFile.keys) }

    func contains(filePath: String, line: Int) -> Bool {
        linesByFile[Self.canonical(filePath)]?.contains(line) ?? false
    }

    static func load(projectPath: String, base: String) throws -> ChangedLines {
        let root = try git(["rev-parse", "--show-toplevel"], in: projectPath)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let diff = try git(
            ["diff", "--unified=0", "--no-color", "--no-ext-diff", "--diff-filter=AMR", base, "--", "*.swift"],
            in: projectPath
        )
        return ChangedLines(linesByFile: parse(diff: diff, root: root))
    }

    static func parse(diff: String, root: String) -> [String: Set<Int>] {
        var result: [String: Set<Int>] = [:]
        var currentFile: String?

        for line in diff.split(separator: "\n", omittingEmptySubsequences: false) {
            if line.hasPrefix("+++ ") {
                let path = line.dropFirst(4)
                currentFile = path.hasPrefix("b/") ? canonical(root + "/" + path.dropFirst(2)) : nil
                continue
            }

            guard line.hasPrefix("@@"), let file = currentFile, let range = addedRange(in: line) else {
                continue
            }

            result[file, default: []].formUnion(range)
        }

        return result
    }

    private static func addedRange(in hunkHeader: Substring) -> ClosedRange<Int>? {
        guard let plus = hunkHeader.split(separator: " ").first(where: { $0.hasPrefix("+") }) else {
            return nil
        }

        let parts = plus.dropFirst().split(separator: ",")
        guard let start = parts.first.flatMap({ Int($0) }) else { return nil }
        let count = parts.count > 1 ? Int(parts[1]) ?? 1 : 1

        guard count > 0 else { return nil }
        return start...(start + count - 1)
    }

    private static func canonical(_ path: String) -> String {
        URL(fileURLWithPath: path).resolvingSymlinksInPath().standardizedFileURL.path
    }

    private static func git(_ arguments: [String], in directory: String) throws -> String {
        let process = Process()
        let output = Pipe()
        let errors = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["-C", directory] + arguments
        process.standardOutput = output
        process.standardError = errors
        try process.run()
        let data = output.fileHandleForReading.readDataToEndOfFile()
        let errorData = errors.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let message = String(data: errorData, encoding: .utf8) ?? ""
            throw ChangedLinesError.gitFailed(arguments: arguments, message: message)
        }

        return String(data: data, encoding: .utf8) ?? ""
    }
}

enum ChangedLinesError: Error, CustomStringConvertible {
    case gitFailed(arguments: [String], message: String)

    var description: String {
        switch self {
        case let .gitFailed(arguments, message):
            "git \(arguments.joined(separator: " ")) failed: \(message.trimmingCharacters(in: .whitespacesAndNewlines))"
        }
    }
}
