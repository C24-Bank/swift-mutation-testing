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
            lines.append("  \(check.passed ? "✓" : "✗") \(check.summary)")
            if case .newUndetected = check {
                lines.append(contentsOf: listed(result.newUndetected))
            }
        }

        if !result.checksNewUndetected, !result.newUndetected.isEmpty {
            lines.append("  ℹ \(result.newUndetectedSummary) since the baseline")
        }

        if let fixed = result.fixedCount, fixed > 0 {
            lines.append("  ℹ \(GateResult.count(fixed, "mutant")) detected now that were undetected in the baseline")
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - Private

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
}
