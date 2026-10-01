extension ExecutionResult {
    var reportStatusReason: String? {
        switch (status, activated) {
        case (.killedByCrash, false): "crash without activation"
        case (.killedByCrash, _): "crash"
        case (.killed, false): "killed without activation"
        case (.timeout, false): "timed out without activation"
        default: nil
        }
    }
}
