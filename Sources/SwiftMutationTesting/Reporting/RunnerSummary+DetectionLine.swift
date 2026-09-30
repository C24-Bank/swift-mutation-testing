extension RunnerSummary {
    var detectionLine: String {
        "Detected: \(detected.count) (killed \(killed.count), timeout \(timeouts.count))"
            + " / Undetected: \(undetected.count) (survived \(survived.count), no coverage \(noCoverage.count))"
    }
}
