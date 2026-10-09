struct DiscoveryInput: Sendable {
    let projectPath: String
    let projectType: ProjectType
    let timeout: Double
    let concurrency: Int
    let noCache: Bool
    let sourcesPath: String
    let excludePatterns: [String]
    var diffBase: String? = nil
    var sonarPropertiesPath: String? = nil
    var excludeCoverageBlocks = false
    let operators: [String]
}
