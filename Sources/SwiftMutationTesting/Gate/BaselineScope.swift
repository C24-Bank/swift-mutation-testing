import Foundation

struct BaselineScope: Sendable, Codable, Equatable {
    let operators: [String]
    let sourcesPath: String
    let excludePatterns: [String]

    init(operators: [String], sourcesPath: String, excludePatterns: [String]) {
        self.operators = operators.sorted()
        self.sourcesPath = sourcesPath
        self.excludePatterns = excludePatterns.sorted()
    }

    init(configuration: RunnerConfiguration) {
        let operators = configuration.filter.operators
        let root = CanonicalPath.make(for: configuration.projectPath)
        let sourcesPath = CanonicalPath.make(
            for: URL(fileURLWithPath: configuration.filter.sourcesPath ?? configuration.projectPath)
                .standardizedFileURL.path
        )

        self.init(
            operators: operators.isEmpty ? DiscoveryPipeline.allOperatorNames : operators,
            sourcesPath: sourcesPath == root ? "." : ProjectRelativePath.make(for: sourcesPath, in: root),
            excludePatterns: configuration.filter.excludePatterns
        )
    }

    func differences(from other: BaselineScope) -> [String] {
        var differences: [String] = []
        if operators != other.operators {
            differences.append("operators: \(other.operators.joined(separator: ", ")) → \(describe(operators))")
        }
        if sourcesPath != other.sourcesPath {
            differences.append("sources path: \(other.sourcesPath) → \(sourcesPath)")
        }
        if excludePatterns != other.excludePatterns {
            differences.append(
                "exclude patterns: \(describe(other.excludePatterns)) → \(describe(excludePatterns))"
            )
        }
        return differences
    }

    private func describe(_ list: [String]) -> String {
        list.isEmpty ? "none" : list.joined(separator: ", ")
    }
}
