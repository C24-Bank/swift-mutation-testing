extension RunnerSummary {
    var fromCache: [ExecutionResult] {
        results.filter(\.fromCache)
    }

    var cacheLine: String? {
        guard !fromCache.isEmpty else { return nil }
        return "Verdicts from cache: \(fromCache.count) of \(results.count)"
    }
}
