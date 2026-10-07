import Foundation

enum StandardError {

    @TaskLocal static var capture: StandardOutput.Capture?

    static func write(_ line: String) {
        if let capture {
            capture.append(line + "\n")
        } else {
            fputs(line + "\n", stderr)
        }
    }
}
