import Foundation

struct RunnerConfiguration: Sendable {
    static let defaultXcodeTimeout: Double = 120.0
    static let defaultSPMTimeout: Double = 30.0
    static let defaultBuildTimeout: Double = 120.0
    static let defaultConcurrency = concurrency(forProcessors: ProcessInfo.processInfo.processorCount)

    /// One worker per processor, less the one the tool itself runs on.
    static func concurrency(forProcessors processorCount: Int) -> Int {
        max(1, processorCount - 1)
    }

    let projectPath: String
    var build: BuildOptions
    var reporting: ReportingOptions
    var filter: FilterOptions
    var gate: GateOptions = GateOptions()

    struct BuildOptions: Sendable {
        var projectType: ProjectType
        /// The workspace or project `xcodebuild` builds; `nil` for a package, or an Xcode root with none.
        var xcodeContainer: XcodeContainer?
        var testTarget: String?
        var timeout: Double
        var buildTimeout: Double
        var concurrency: Int
        var noCache: Bool
        var testingFramework: TestingFramework = .swiftTesting
        /// `reproduce`: one mutant, the whole suite with no stop at the first failure, the sandbox kept and
        /// recorded here.
        var reproduction: Reproduction?

        var reproducing: Bool { reproduction != nil }
    }

    struct ReportingOptions: Sendable {
        var output: String?
        var htmlOutput: String?
        var sonarOutput: String?
        var sarifOutput: String?
        var markdownOutput: String?
        var keepLogsPath: String?
        var quiet: Bool
    }

    struct FilterOptions: Sendable {
        var sourcesPath: String?
        var excludePatterns: [String]
        var operators: [String]
    }

    struct GateOptions: Sendable {
        var policy = GatePolicy()
        var baselinePath: String?
        var writeBaselinePath: String?

        var isActive: Bool {
            !policy.isEmpty || baselinePath != nil
        }
    }
}
