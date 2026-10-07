import Foundation

/// The tool's warnings and errors: written to stderr, or — inside a test that installed one — to a capture.
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
