import Foundation

enum TargetedSuites {

    static let suffix = "Tests"

    static func declared(in testFilePaths: [String]) -> Set<String> {
        Set(
            testFilePaths.compactMap { path in
                let name = URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent

                guard name.hasSuffix(suffix), let content = try? String(contentsOfFile: path, encoding: .utf8)
                else { return nil }

                return declares(name, in: content) ? name : nil
            }
        )
    }

    static func suite(for sourcePath: String, among suites: Set<String>) -> String? {
        let candidate = URL(fileURLWithPath: sourcePath).deletingPathExtension().lastPathComponent + suffix
        return suites.contains(candidate) ? candidate : nil
    }

    // MARK: - Private

    private static func declares(_ name: String, in content: String) -> Bool {
        ["struct", "class", "enum", "actor"].contains { content.contains("\($0) \(name)") }
    }
}
