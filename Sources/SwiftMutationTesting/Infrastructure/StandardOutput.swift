import Synchronization

enum StandardOutput {

    @TaskLocal static var capture: Capture?

    static func write(_ line: String = "") {
        if let capture {
            capture.append(line + "\n")
        } else {
            print(line)
        }
    }

    final class Capture: Sendable {

        var contents: String {
            buffer.withLock { $0 }
        }

        func append(_ text: String) {
            buffer.withLock { $0 += text }
        }

        // MARK: - Private

        private let buffer = Mutex("")
    }
}
