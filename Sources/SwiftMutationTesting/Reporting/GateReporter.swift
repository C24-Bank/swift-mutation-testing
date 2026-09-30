import Foundation

struct GateReporter: Sendable {
    static let listedLimit = 20

    let projectRoot: String

    func report(_ result: GateResult) {
        StandardOutput.write(format(result))
    }

    func format(_ result: GateResult) -> String {
        var lines = ["", "Quality gate: \(result.passed ? "PASSED" : "FAILED")"]

        for check in result.checks {
            lines.append("  \(check.passed ? "✓" : "✗") \(describe(check))")
            if case .newUndetected = check {
                lines.append(contentsOf: listed(result.newUndetected))
            }
        }

        let checksNewUndetected = result.checks.contains {
            if case .newUndetected = $0 { return true }
            return false
        }
        if !checksNewUndetected, !result.newUndetected.isEmpty {
            lines.append("  ℹ \(count(result.newUndetected.count, "new undetected mutant")) since the baseline")
        }

        if let fixed = result.fixedCount, fixed > 0 {
            lines.append("  ℹ \(count(fixed, "mutant")) detected now that were undetected in the baseline")
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - Private

    private func describe(_ check: GateResult.Check) -> String {
        switch check {
        case .minScore(let score, let minimum):
            return "score \(percent(score)) \(check.passed ? "≥" : "<") \(percent(minimum))"

        case .scoreDrop(let drop, let maximum):
            let comparison = check.passed ? "≤" : ">"
            guard drop > 0 else { return "score did not drop (max drop \(points(maximum)))" }
            return "score drop \(points(drop)) \(comparison) \(points(maximum))"

        case .newUndetected(let found, let maximum):
            return "\(count(found, "new undetected mutant")) (max \(maximum))"
        }
    }

    private func listed(_ results: [ExecutionResult]) -> [String] {
        var lines = results.prefix(Self.listedLimit).map { result in
            let descriptor = result.descriptor
            let location = "\(ProjectRelativePath.make(for: descriptor.filePath, in: projectRoot)):\(descriptor.line)"
            return "      \(location)   \(descriptor.operatorIdentifier)   \(descriptor.description)"
        }
        if results.count > Self.listedLimit {
            lines.append("      and \(results.count - Self.listedLimit) more — see the report")
        }
        return lines
    }

    private func percent(_ value: Double) -> String {
        String(format: "%.1f%%", value)
    }

    private func points(_ value: Double) -> String {
        String(format: "%.1f pts", value)
    }

    private func count(_ value: Int, _ noun: String) -> String {
        "\(value) \(noun)\(value == 1 ? "" : "s")"
    }
}
