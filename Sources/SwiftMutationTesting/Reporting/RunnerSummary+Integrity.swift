extension RunnerSummary {
    var integrityWarnings: [ExecutionResult] {
        results.filter { $0.activated == false && ($0.status.isKill || $0.status == .timeout) }
    }

    var activationNotMeasured: [ExecutionResult] {
        results.filter { $0.activated == nil && $0.status != .unviable }
    }
}
