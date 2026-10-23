struct ParsedArguments: Sendable {
    var projectPath: String = "."
    var showVersion: Bool = false
    var showHelp: Bool = false
    var showInit: Bool = false
    var build: BuildOptions = BuildOptions()
    var reporting: ReportingOptions = ReportingOptions()
    var filter: FilterOptions = FilterOptions()

    struct BuildOptions: Sendable {
        var scheme: String?
        var destination: String?
        var testTarget: String?
        var timeout: Double?
        var buildTimeout: Double?
        var concurrency: Int?
        var noCache: Bool = false
        var testingFramework: String?
        var cachePath: String?
        var inPlace: Bool = false
        var testPlan: String?
        var cleanupSimulators: Bool = false
    }

    struct ReportingOptions: Sendable {
        var output: String?
        var htmlOutput: String?
        var sonarOutput: String?
        var keepLogsPath: String?
        var quiet: Bool = false
        var summaryOutput: String?
    }

    struct FilterOptions: Sendable {
        var sourcesPath: String?
        var excludePatterns: [String] = []
        var diffBase: String?
        var sonarPropertiesPath: String?
        var excludeCoverageBlocks = false
        var discoverOnly = false
        var selectTests = false
        var verifyKills = false
        var skipIncompatible = false
        var mutantIDs: [String] = []
        var operators: [String] = []
        var disabledMutators: [String] = []
    }
}
