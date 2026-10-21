import Foundation

struct FileDiscoveryStage: Sendable {
    private static let fixedExclusions: [String] = [
        "/Tests/",
        "/Mocks/",
        "/Stubs/",
        "/Fakes/",
        "/TestHelpers/",
        "/TestSupport/",
        "Tests.swift",
        "Mock.swift",
        "Spec.swift",
        "/.build/",
        "/.swift-mutation-testing-derived-data/",
        "/\(CacheStore.directoryName)/",
        "/DerivedData/",
    ]

    func run(input: DiscoveryInput) throws -> [SourceFile] {
        let sonarExclusions = try input.sonarPropertiesPath.map { try SonarExclusions.load(propertiesPath: $0) }

        var sourceFiles: [SourceFile] = []

        for fileURL in try candidateFiles(in: input.sourcesPath) {
            guard fileURL.pathExtension == "swift" else {
                continue
            }

            let path = fileURL.path

            guard !isExcluded(path: path, excludePatterns: input.excludePatterns),
                sonarExclusions?.excludes(path: path) != true
            else {
                continue
            }

            guard let content = try? String(contentsOf: fileURL, encoding: .utf8) else {
                continue
            }

            sourceFiles.append(SourceFile(path: path, content: content))
        }

        return sourceFiles
    }

    /// Files under each comma-separated sources path; a path that is a file stands for itself.
    private func candidateFiles(in sourcesPaths: String) throws -> [URL] {
        var files: [URL] = []

        for rawPath in sourcesPaths.split(separator: ",") {
            let path = rawPath.trimmingCharacters(in: .whitespaces)
            var isDirectory: ObjCBool = false

            guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory) else {
                throw FileDiscoveryError.sourcesPathNotFound(path)
            }

            let url = URL(fileURLWithPath: path).absoluteURL
            guard isDirectory.boolValue else {
                files.append(url)
                continue
            }

            guard
                let enumerator = FileManager.default.enumerator(
                    at: url,
                    includingPropertiesForKeys: [.isRegularFileKey],
                    options: [.skipsHiddenFiles]
                )
            else { throw FileDiscoveryError.sourcesPathNotFound(path) }

            for case let fileURL as URL in enumerator {
                files.append(fileURL)
            }
        }

        return files
    }

    private func isExcluded(path: String, excludePatterns: [String]) -> Bool {
        for pattern in Self.fixedExclusions {
            if pattern.hasSuffix(".swift") {
                if path.hasSuffix(pattern) {
                    return true
                }
            } else if path.contains(pattern) {
                return true
            }
        }

        return excludePatterns.contains { path.contains($0) }
    }
}
