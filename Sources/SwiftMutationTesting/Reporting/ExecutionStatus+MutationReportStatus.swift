extension ExecutionStatus {
    var mutationReportStatus: String {
        switch self {
        case .killed, .killedByCrash:
            return "Killed"

        case .survived:
            return "Survived"

        case .unviable:
            return "CompileError"

        case .timeout:
            return "Timeout"

        case .noCoverage:
            return "NoCoverage"
        }
    }

    var mutationReportStatusReason: String? {
        guard case .killedByCrash = self else { return nil }
        return "crash"
    }
}
