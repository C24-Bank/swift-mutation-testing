struct ParsedArguments: Sendable {
    enum Command: Sendable, Equatable {
        case run
        case plan
        case merge
        case reproduce
    }

    var command: Command = .run
    var projectPath: String = "."
    var showVersion: Bool = false
    var showHelp: Bool = false
    var showInit: Bool = false
    var plan: PlanOptions = PlanOptions()
    var build: BuildOptions = BuildOptions()
    var reporting: ReportingOptions = ReportingOptions()
    var filter: FilterOptions = FilterOptions()
    var gate: GateOptions = GateOptions()

    struct BuildOptions: Sendable {
        var scheme: String?
        var destination: String?
        var testTarget: String?
        var timeout: Double?
        var buildTimeout: Double?
        var concurrency: Int?
        var noCache: Bool = false
        var testingFramework: String?
        var workspace: String?
        var xcodeProject: String?
    }

    struct ReportingOptions: Sendable {
        var output: String?
        var htmlOutput: String?
        var sonarOutput: String?
        var sarifOutput: String?
        var markdownOutput: String?
        var keepLogsPath: String?
        var quiet: Bool = false
    }

    struct FilterOptions: Sendable {
        var sourcesPath: String?
        var excludePatterns: [String] = []
        var operators: [String] = []
        var disabledMutators: [String] = []
        var operatorTier: String?
    }

    struct PlanOptions: Sendable {
        /// `plan`: where the plan is written. `run`, `merge`, `reproduce`: the plan to work from.
        var path: String?
        var shard: String?
        /// `merge`: the result files to join.
        var results: [String] = []
        /// `reproduce`: the fingerprint or report id of the mutant.
        var mutant: String?
        /// `merge`: the project whose sources the reports embed and whose configuration applies; its
        /// positionals are the results, so the project path is a flag.
        var projectPath: String?
    }

    struct GateOptions: Sendable {
        var minScore: Double?
        var baseline: String?
        var maxScoreDrop: Double?
        var maxNewSurvivors: Int?
        var writeBaseline: String?
    }
}
