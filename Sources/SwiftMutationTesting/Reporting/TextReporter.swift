import Foundation

struct TextReporter: Sendable {
    init(projectRoot: String = "") {
        resolvedRoot =
            projectRoot.isEmpty
            ? ""
            : URL(fileURLWithPath: projectRoot).resolvingSymlinksInPath().path
    }

    private let resolvedRoot: String

    func report(_ summary: RunnerSummary) {
        StandardOutput.write(format(summary))
    }

    func format(_ summary: RunnerSummary) -> String {
        var lines: [String] = []

        lines.append("")
        lines.append("Results by file:")
        for (filePath, fileResults) in summary.resultsByFile.sorted(by: { $0.key < $1.key }) {
            let file = RunnerSummary(results: fileResults, totalDuration: 0)
            let score = String(format: "%.1f", file.score)
            let stats = [
                "killed: \(file.killed.count)",
                "survived: \(file.survived.count)",
                "timeout: \(file.timeouts.count)",
                "unviable: \(file.unviable.count)",
            ].joined(separator: "   ")
            lines.append("  \(relative(filePath))    score: \(score)%   \(stats)")
        }

        let unkilledMutants = summary.survived + summary.noCoverage
        if !unkilledMutants.isEmpty {
            lines.append("")
            lines.append("Survived mutants:")
            let sorted = unkilledMutants.sorted {
                ($0.descriptor.filePath, $0.descriptor.line) < ($1.descriptor.filePath, $1.descriptor.line)
            }
            for result in sorted {
                let desc = result.descriptor
                lines.append(
                    "  \(relative(desc.filePath)):\(desc.line):\(desc.column)"
                        + "   \(desc.operatorIdentifier)"
                )
            }
        }

        lines.append(contentsOf: integritySection(summary))

        lines.append("")
        lines.append("Overall mutation score: \(String(format: "%.1f", summary.score))%")
        lines.append(summary.detectionLine)
        lines.append(
            "Killed: \(summary.killed.count)"
                + " / Survived: \(summary.survived.count)"
                + " / Timeouts: \(summary.timeouts.count)"
                + " / Unviable: \(summary.unviable.count)"
                + " / NoCoverage: \(summary.noCoverage.count)"
        )
        if !summary.activationNotMeasured.isEmpty {
            lines.append("Activation not measured: \(GateResult.count(summary.activationNotMeasured.count, "mutant"))")
        }
        if let cacheLine = summary.cacheLine {
            lines.append(cacheLine)
        }
        lines.append("Total duration: \(formattedDuration(summary.totalDuration))")

        return lines.joined(separator: "\n")
    }

    static let integrityWarningsListed = 10

    private func integritySection(_ summary: RunnerSummary) -> [String] {
        let warnings = summary.integrityWarnings.sorted {
            ($0.descriptor.filePath, $0.descriptor.line) < ($1.descriptor.filePath, $1.descriptor.line)
        }
        guard !warnings.isEmpty else { return [] }

        var lines = [""]
        lines.append("Integrity warnings (\(warnings.count)): killed or timed out without the mutated code running")
        for result in warnings.prefix(Self.integrityWarningsListed) {
            let desc = result.descriptor
            lines.append(
                "  \(relative(desc.filePath)):\(desc.line):\(desc.column)"
                    + "   \(desc.operatorIdentifier)   \(result.reportStatusReason ?? "")"
            )
        }
        if warnings.count > Self.integrityWarningsListed {
            lines.append("  and \(warnings.count - Self.integrityWarningsListed) more — see the JSON report")
        }
        return lines
    }

    private func formattedDuration(_ seconds: Double) -> String {
        let totalSeconds = Int(seconds)
        let minutes = totalSeconds / 60
        let remainingSeconds = totalSeconds % 60
        if minutes > 0 {
            return "\(minutes)m \(remainingSeconds)s"
        }
        return String(format: "%.1fs", seconds)
    }

    private func relative(_ path: String) -> String {
        guard !resolvedRoot.isEmpty else { return path }
        let resolvedPath = URL(fileURLWithPath: path).resolvingSymlinksInPath().path
        guard resolvedPath.hasPrefix(resolvedRoot) else { return path }
        return String(resolvedPath.dropFirst(resolvedRoot.count).drop(while: { $0 == "/" }))
    }
}
