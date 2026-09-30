struct RunnerSummary: Sendable {
    let results: [ExecutionResult]
    let totalDuration: Double

    var killed: [ExecutionResult] {
        results.filter {
            switch $0.status {
            case .killed, .killedByCrash: return true
            default: return false
            }
        }
    }

    var survived: [ExecutionResult] {
        results.filter { $0.status == .survived }
    }

    var unviable: [ExecutionResult] {
        results.filter { $0.status == .unviable }
    }

    var timeouts: [ExecutionResult] {
        results.filter { $0.status == .timeout }
    }

    var noCoverage: [ExecutionResult] {
        results.filter { $0.status == .noCoverage }
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
}
