import Foundation

struct MutantLogWriter: Sendable {

    init?(directory: String?) {
        guard let directory else { return nil }
        self.directory = URL(fileURLWithPath: directory)
    }

    private let directory: URL

    func write(
        mutant: MutantDescriptor,
        status: ExecutionStatus,
        duration: Double,
        output: String
    ) {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let contents = header(mutant: mutant, status: status, duration: duration) + "\n" + output

        try? contents.write(
            to: directory.appendingPathComponent("\(mutant.id).log"),
            atomically: true,
            encoding: .utf8
        )
    }

    // MARK: - Private

    private func header(mutant: MutantDescriptor, status: ExecutionStatus, duration: Double) -> String {
        """
        mutant:   \(mutant.id)
        location: \(mutant.filePath):\(mutant.line):\(mutant.column)
        operator: \(mutant.operatorIdentifier)
        mutation: \(mutant.originalText) → \(mutant.mutatedText)
        status:   \(statusLine(status))
        duration: \(String(format: "%.2f", duration))s
        ---
        """
    }

    private func statusLine(_ status: ExecutionStatus) -> String {
        switch status {
        case .killed(let test): "Killed by \(test)"
        case .killedByCrash: "Crash"
        case .survived: "Survived"
        case .unviable: "Unviable"
        case .timeout: "Timeout"
        case .noCoverage: "NoCoverage"
        }
    }
}
