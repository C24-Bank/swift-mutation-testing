import Foundation

/// Runs one mutant of a plan the way someone investigating a verdict needs it: the whole suite, no stop at
/// the first failure, the sandbox left in place, and everything printed — where the sandbox is, what the
/// mutation changed, what the tests said, and the verdict with its reason.
struct Reproducer: Sendable {
    func reproduce(
        _ reference: String,
        plan: Plan,
        configuration: RunnerConfiguration,
        launcher: any ProcessLaunching
    ) async throws -> ExitCode {
        let (index, mutant) = try Self.mutant(matching: reference, in: plan)

        var configuration = configuration
        let reproduction = Reproduction()
        configuration.build.reproduction = reproduction
        configuration.build.noCache = true
        configuration.build.concurrency = 1
        let logs = configuration.reporting.keepLogsPath ?? Self.logsDirectory(for: mutant).path
        configuration.reporting.keepLogsPath = logs
        configuration.reporting.quiet = true

        let input = try await PlanMaterializer().materialize(
            plan: plan,
            projectPath: configuration.projectPath,
            execution: .init(timeout: configuration.build.timeout, concurrency: 1, noCache: true),
            mutants: [mutant]
        )

        let id = Plan.mutantID(at: index)
        StandardOutput.write(
            "Reproducing \(id) (\(mutant.fingerprint)): \(mutant.operatorIdentifier) at \(mutant.file):\(mutant.line)"
        )
        StandardOutput.write("")

        let results = try await MutantExecutor(configuration: configuration, launcher: launcher).execute(input)

        for sandbox in reproduction.keptSandboxes {
            StandardOutput.write("Sandbox: \(sandbox)")
        }
        StandardOutput.write("")
        StandardOutput.write(Self.diff(of: mutant, in: configuration.projectPath))
        StandardOutput.write("")
        StandardOutput.write("Tests:")
        StandardOutput.write(Self.testOutput(of: id, in: logs))
        StandardOutput.write("")

        let (line, exit) = Self.verdict(of: results)
        StandardOutput.write(line)
        return exit
    }

    static func verdict(of results: [ExecutionResult]) -> (line: String, exit: ExitCode) {
        guard let result = results.first else {
            return ("Verdict: none — the mutant was not run", .error)
        }
        let reason = result.reportStatusReason ?? result.status.mutationReportStatusReason
        return ("Verdict: \(describe(result.status))" + (reason.map { " (\($0))" } ?? ""), .success)
    }

    /// A report id (`swift-mutation-testing_12`), a full fingerprint, or a prefix of one that fits one mutant.
    static func mutant(matching reference: String, in plan: Plan) throws -> (Int, Plan.Mutant) {
        let prefix = "swift-mutation-testing_"
        if reference.hasPrefix(prefix), let index = Int(reference.dropFirst(prefix.count)) {
            guard plan.mutants.indices.contains(index) else { throw PlanError.unknownMutant(reference) }
            return (index, plan.mutants[index])
        }

        if let exact = plan.mutants.firstIndex(where: { $0.fingerprint == reference }) {
            return (exact, plan.mutants[exact])
        }
        let matches = plan.mutants.enumerated().filter { $0.element.fingerprint.hasPrefix(reference) }
        guard reference.count >= 6, matches.count == 1, let match = matches.first else {
            throw PlanError.unknownMutant(reference)
        }
        return (match.offset, match.element)
    }

    // MARK: - Private

    private static func logsDirectory(for mutant: Plan.Mutant) -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("swift-mutation-testing-reproduce")
            .appendingPathComponent(mutant.fingerprint)
    }

    static func diff(of mutant: Plan.Mutant, in projectPath: String) -> String {
        let path = PlanMaterializer.absolute(mutant.file, in: projectPath)
        guard let original = try? String(contentsOfFile: path, encoding: .utf8) else {
            return "--- \(mutant.file):\(mutant.line): \(mutant.original) → \(mutant.replacement)"
        }
        let mutated = MutationRewriter().rewrite(
            source: original,
            applying: MutationPoint(
                operatorIdentifier: mutant.operatorIdentifier, filePath: path, line: mutant.line, column: mutant.column,
                utf8Offset: mutant.utf8Start, originalText: mutant.original, mutatedText: mutant.replacement,
                replacement: mutant.replacementKind, description: mutant.description
            )
        )
        let before = original.components(separatedBy: "\n")
        let after = mutated.components(separatedBy: "\n")
        var lines = ["--- \(mutant.file):\(mutant.line)"]
        for (number, pair) in zip(before, after).enumerated() where pair.0 != pair.1 {
            lines.append("-\(number + 1): \(pair.0)")
            lines.append("+\(number + 1): \(pair.1)")
        }
        if before.count != after.count {
            lines.append("(the mutation changes the number of lines; see \(mutant.original) → \(mutant.replacement))")
        }
        return lines.joined(separator: "\n")
    }

    private static func testOutput(of id: String, in logs: String) -> String {
        let path = URL(fileURLWithPath: logs).appendingPathComponent("\(id).log").path
        guard let log = try? String(contentsOfFile: path, encoding: .utf8) else {
            return "(no test output was captured; the mutant did not reach its tests)"
        }
        return log
    }

    private static func describe(_ status: ExecutionStatus) -> String {
        switch status {
        case .killed(let by): "killed by \(by)"
        case .killedByCrash: "killed, the test process crashed"
        case .survived: "survived"
        case .unviable: "unviable, the mutant does not compile"
        case .timeout: "timeout"
        case .noCoverage: "no coverage, no test ran the mutated code"
        }
    }
}
