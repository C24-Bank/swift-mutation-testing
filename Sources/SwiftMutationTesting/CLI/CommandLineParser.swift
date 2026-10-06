struct CommandLineParser: Sendable {
    private struct FlagValues {
        var scheme: String?
        var destination: String?
        var testTarget: String?
        var timeout: Double?
        var buildTimeout: Double?
        var concurrency: Int?
        var noCache = false
        var testingFramework: String?
        var workspace: String?
        var xcodeProject: String?
        var output: String?
        var htmlOutput: String?
        var sonarOutput: String?
        var sarifOutput: String?
        var markdownOutput: String?
        var keepLogsPath: String?
        var quiet = false
        var sourcesPath: String?
        var excludePatterns: [String] = []
        var operators: [String] = []
        var disabledMutators: [String] = []
        var operatorTier: String?
        var gate = ParsedArguments.GateOptions()
        var plan = ParsedArguments.PlanOptions()
    }

    func parse(_ arguments: [String]) throws -> ParsedArguments {
        guard !arguments.isEmpty else {
            return ParsedArguments()
        }

        switch arguments[0] {
        case "--help", "-h":
            return ParsedArguments(showHelp: true)

        case "--version":
            return ParsedArguments(showVersion: true)

        default:
            break
        }

        var remaining = arguments
        var projectPath = "."

        if remaining[0] == "init" {
            remaining.removeFirst()
            if let next = remaining.first, !next.hasPrefix("-") {
                projectPath = next
            }

            return ParsedArguments(projectPath: projectPath, showInit: true)
        }

        let command = Self.command(named: remaining[0])
        if command != .run || remaining[0] == "run" {
            remaining.removeFirst()
        }

        var positionals: [String] = []
        while let next = remaining.first, !next.hasPrefix("-") {
            positionals.append(next)
            remaining.removeFirst()
        }

        var flags = try parseFlags(remaining)
        projectPath = try apply(positionals, of: command, to: &flags)

        if command == .plan {
            flags.plan.path = flags.output
            flags.output = nil
        }
        if flags.plan.shard != nil, command != .run {
            throw UsageError(message: "--shard only applies to run")
        }
        if let path = flags.plan.projectPath {
            guard command == .merge else {
                throw UsageError(message: "--project-path only applies to merge; give the project path as an argument")
            }
            projectPath = path
        }

        return parsedArguments(command: command, projectPath: projectPath, flags: flags)
    }

    private static func command(named word: String) -> ParsedArguments.Command {
        switch word {
        case "plan": .plan
        case "merge": .merge
        case "reproduce": .reproduce
        default: .run
        }
    }

    /// What the words before the flags mean for each command; returns the project path.
    private func apply(
        _ positionals: [String], of command: ParsedArguments.Command, to flags: inout FlagValues
    ) throws -> String {
        switch command {
        case .run, .plan:
            guard positionals.count <= 1 else {
                throw UsageError(message: "unexpected argument '\(positionals[1])'")
            }
            return positionals.first ?? "."

        case .merge:
            guard !positionals.isEmpty else {
                throw UsageError(message: "merge needs the result files to join")
            }
            flags.plan.results = positionals
            return "."

        case .reproduce:
            guard let mutant = positionals.first else {
                throw UsageError(
                    message: "reproduce needs a mutant: a fingerprint or an id such as swift-mutation-testing_12")
            }
            guard positionals.count <= 2 else {
                throw UsageError(message: "unexpected argument '\(positionals[2])'")
            }
            flags.plan.mutant = mutant
            return positionals.count == 2 ? positionals[1] : "."
        }
    }

    private func parsedArguments(
        command: ParsedArguments.Command, projectPath: String, flags: FlagValues
    ) -> ParsedArguments {
        ParsedArguments(
            command: command,
            projectPath: projectPath,
            plan: flags.plan,
            build: .init(
                scheme: flags.scheme,
                destination: flags.destination,
                testTarget: flags.testTarget,
                timeout: flags.timeout,
                buildTimeout: flags.buildTimeout,
                concurrency: flags.concurrency,
                noCache: flags.noCache,
                testingFramework: flags.testingFramework,
                workspace: flags.workspace,
                xcodeProject: flags.xcodeProject
            ),
            reporting: .init(
                output: flags.output,
                htmlOutput: flags.htmlOutput,
                sonarOutput: flags.sonarOutput,
                sarifOutput: flags.sarifOutput,
                markdownOutput: flags.markdownOutput,
                keepLogsPath: flags.keepLogsPath,
                quiet: flags.quiet
            ),
            filter: .init(
                sourcesPath: flags.sourcesPath,
                excludePatterns: flags.excludePatterns,
                operators: flags.operators,
                disabledMutators: flags.disabledMutators,
                operatorTier: flags.operatorTier
            ),
            gate: flags.gate
        )
    }

    private func parseFlags(_ arguments: [String]) throws -> FlagValues {
        var values = FlagValues()
        var index = 0

        while index < arguments.count {
            try applyFlag(arguments[index], to: &values, at: &index, in: arguments)
            index += 1
        }

        return values
    }

    private func applyFlag(
        _ flag: String,
        to values: inout FlagValues,
        at index: inout Int,
        in arguments: [String]
    ) throws {
        if try applyBuildFlag(flag, to: &values, at: &index, in: arguments) { return }
        if try applyReportingFlag(flag, to: &values, at: &index, in: arguments) { return }
        if try applyFilterFlag(flag, to: &values, at: &index, in: arguments) { return }
        if try applyGateFlag(flag, to: &values, at: &index, in: arguments) { return }
        if try applyPlanFlag(flag, to: &values, at: &index, in: arguments) { return }

        throw UsageError(message: "unknown option '\(flag)'")
    }

    private func applyPlanFlag(
        _ flag: String,
        to values: inout FlagValues,
        at index: inout Int,
        in arguments: [String]
    ) throws -> Bool {
        switch flag {
        case "--plan":
            values.plan.path = try nextValue(for: flag, at: &index, in: arguments)

        case "--project-path":
            values.plan.projectPath = try nextValue(for: flag, at: &index, in: arguments)

        case "--shard":
            let raw = try nextValue(for: flag, at: &index, in: arguments)
            guard Shard(parsing: raw) != nil else {
                throw UsageError(message: PlanError.invalidShard(raw).errorDescription ?? raw)
            }
            values.plan.shard = raw

        default:
            return false
        }
        return true
    }

    private func applyBuildFlag(
        _ flag: String,
        to values: inout FlagValues,
        at index: inout Int,
        in arguments: [String]
    ) throws -> Bool {
        switch flag {
        case "--scheme":
            values.scheme = try nextValue(for: flag, at: &index, in: arguments)

        case "--destination":
            values.destination = try nextValue(for: flag, at: &index, in: arguments)

        case "--target":
            values.testTarget = try nextValue(for: flag, at: &index, in: arguments)

        case "--workspace":
            values.workspace = try nextValue(for: flag, at: &index, in: arguments)

        case "--project":
            values.xcodeProject = try nextValue(for: flag, at: &index, in: arguments)

        case "--timeout":
            values.timeout = try nextDouble(for: flag, at: &index, in: arguments)

        case "--build-timeout":
            values.buildTimeout = try nextDouble(for: flag, at: &index, in: arguments)

        case "--concurrency":
            values.concurrency = try nextInt(for: flag, at: &index, in: arguments)

        case "--no-cache":
            values.noCache = true

        case "--testing-framework":
            values.testingFramework = try nextValue(for: flag, at: &index, in: arguments)

        default:
            return false
        }
        return true
    }

    private func applyReportingFlag(
        _ flag: String,
        to values: inout FlagValues,
        at index: inout Int,
        in arguments: [String]
    ) throws -> Bool {
        switch flag {
        case "--output":
            values.output = try nextValue(for: flag, at: &index, in: arguments)

        case "--html-output":
            values.htmlOutput = try nextValue(for: flag, at: &index, in: arguments)

        case "--sonar-output":
            values.sonarOutput = try nextValue(for: flag, at: &index, in: arguments)

        case "--sarif-output":
            values.sarifOutput = try nextValue(for: flag, at: &index, in: arguments)

        case "--markdown-output":
            values.markdownOutput = try nextValue(for: flag, at: &index, in: arguments)

        case "--keep-logs":
            values.keepLogsPath = try nextValue(for: flag, at: &index, in: arguments)

        case "--quiet":
            values.quiet = true

        default:
            return false
        }
        return true
    }

    private func applyFilterFlag(
        _ flag: String,
        to values: inout FlagValues,
        at index: inout Int,
        in arguments: [String]
    ) throws -> Bool {
        switch flag {
        case "--sources-path":
            values.sourcesPath = try nextValue(for: flag, at: &index, in: arguments)

        case "--exclude":
            values.excludePatterns.append(try nextValue(for: flag, at: &index, in: arguments))

        case "--operator":
            values.operators.append(try nextValue(for: flag, at: &index, in: arguments))

        case "--disable-mutator":
            values.disabledMutators.append(try nextValue(for: flag, at: &index, in: arguments))

        case "--operator-tier":
            values.operatorTier = try nextValue(for: flag, at: &index, in: arguments)

        default:
            return false
        }
        return true
    }

    private func applyGateFlag(
        _ flag: String,
        to values: inout FlagValues,
        at index: inout Int,
        in arguments: [String]
    ) throws -> Bool {
        switch flag {
        case "--min-score":
            values.gate.minScore = try nextNonNegativeDouble(for: flag, at: &index, in: arguments)

        case "--baseline":
            values.gate.baseline = try nextValue(for: flag, at: &index, in: arguments)

        case "--max-score-drop":
            values.gate.maxScoreDrop = try nextNonNegativeDouble(for: flag, at: &index, in: arguments)

        case "--max-new-survivors":
            values.gate.maxNewSurvivors = try nextInt(for: flag, at: &index, in: arguments)

        case "--max-integrity-warnings":
            values.gate.maxIntegrityWarnings = try nextInt(for: flag, at: &index, in: arguments)

        case "--write-baseline":
            values.gate.writeBaseline = try nextValue(for: flag, at: &index, in: arguments)

        default:
            return false
        }
        return true
    }

    private func nextValue(for flag: String, at index: inout Int, in arguments: [String]) throws -> String {
        let next = index + 1
        guard next < arguments.count else {
            throw UsageError(message: "\(flag) requires a value")
        }
        index = next
        return arguments[next]
    }

    private func nextDouble(for flag: String, at index: inout Int, in arguments: [String]) throws -> Double {
        let raw = try nextValue(for: flag, at: &index, in: arguments)
        guard let value = Double(raw), value > 0 else {
            throw UsageError(message: "\(flag) must be a positive number")
        }
        return value
    }

    private func nextNonNegativeDouble(for flag: String, at index: inout Int, in arguments: [String]) throws -> Double {
        let raw = try nextValue(for: flag, at: &index, in: arguments)
        guard let value = Double(raw), value >= 0 else {
            throw UsageError(message: "\(flag) must be a number >= 0")
        }
        return value
    }

    private func nextInt(for flag: String, at index: inout Int, in arguments: [String]) throws -> Int {
        let raw = try nextValue(for: flag, at: &index, in: arguments)
        guard let value = Int(raw) else {
            throw UsageError(message: "\(flag) must be an integer")
        }
        return value
    }

}
