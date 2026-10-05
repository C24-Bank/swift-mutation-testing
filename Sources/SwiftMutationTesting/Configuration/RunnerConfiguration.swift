import Foundation

struct RunnerConfiguration: Sendable {
    static let defaultXcodeTimeout: Double = 120.0
    static let defaultSPMTimeout: Double = 30.0
    static let defaultBuildTimeout: Double = 120.0
    static let defaultConcurrency: Int = max(1, ProcessInfo.processInfo.processorCount - 1)

    let projectPath: String
    var build: BuildOptions
    var reporting: ReportingOptions
    var filter: FilterOptions
    var gate: GateOptions = GateOptions()

    struct BuildOptions: Sendable {
        var projectType: ProjectType
        var testTarget: String?
        var timeout: Double
        var buildTimeout: Double
        var concurrency: Int
        var noCache: Bool
        var testingFramework: TestingFramework = .swiftTesting
        /// `reproduce`: one mutant, the whole suite with no stop at the first failure, the sandbox kept.
        var reproducing: Bool = false
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
