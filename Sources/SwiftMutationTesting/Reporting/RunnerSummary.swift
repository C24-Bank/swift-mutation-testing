/// A run's results sorted into what every report shows — computed once, so the reports only format it and
/// cannot count differently.
struct RunnerSummary: Sendable {
    let results: [ExecutionResult]
    let totalDuration: Double

    let killed: [ExecutionResult]
    let survived: [ExecutionResult]
    let unviable: [ExecutionResult]
    let timeouts: [ExecutionResult]
    let noCoverage: [ExecutionResult]

    init(results: [ExecutionResult], totalDuration: Double) {
        self.results = results
        self.totalDuration = totalDuration

        var killed: [ExecutionResult] = []
        var survived: [ExecutionResult] = []
        var unviable: [ExecutionResult] = []
        var timeouts: [ExecutionResult] = []
        var noCoverage: [ExecutionResult] = []

        for result in results {
            switch result.status {
            case .killed, .killedByCrash: killed.append(result)
            case .survived: survived.append(result)
            case .unviable: unviable.append(result)
            case .timeout: timeouts.append(result)
            case .noCoverage: noCoverage.append(result)
            }
        }

        self.killed = killed
        self.survived = survived
        self.unviable = unviable
        self.timeouts = timeouts
        self.noCoverage = noCoverage
    }

    var detected: [ExecutionResult] {
        killed + timeouts
    }

    var undetected: [ExecutionResult] {
        survived + noCoverage
    }

    var score: Double {
        let valid = detected.count + undetected.count

        guard valid > 0 else { return 100.0 }

        return Double(detected.count) / Double(valid) * 100.0
    }

    var resultsByFile: [String: [ExecutionResult]] {
        Dictionary(grouping: results, by: { $0.descriptor.filePath })
    }

    /// One summary per file, in path order.
    var files: [(path: String, summary: RunnerSummary)] {
        resultsByFile.sorted { $0.key < $1.key }.map { ($0.key, RunnerSummary(results: $0.value, totalDuration: 0)) }
    }

    /// `results` in source order: by file, then line, then column.
    static func byLocation(_ results: [ExecutionResult]) -> [ExecutionResult] {
        results.sorted {
            ($0.descriptor.filePath, $0.descriptor.line, $0.descriptor.column)
                < ($1.descriptor.filePath, $1.descriptor.line, $1.descriptor.column)
        }
    }
}
