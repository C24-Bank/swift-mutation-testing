import Foundation

@testable import SwiftMutationTesting

actor SPMErrorAtLineMock: ProcessLaunching {
    private let locations: [(fileName: String, line: Int)]
    private var buildCallCount = 0

    init(fileName: String = "Foo.swift", line: Int) {
        locations = [(fileName: fileName, line: line)]
    }

    init(locations: [(fileName: String, line: Int)]) {
        self.locations = locations
    }

    func launch(
        executableURL: URL,
        arguments: [String],
        workingDirectoryURL: URL,
        timeout: Double
    ) async throws -> Int32 { 0 }

    func launchCapturing(
        _ request: ProcessRequest
    ) async throws -> (exitCode: Int32, output: String) {
        guard request.arguments.first == "build" else { return (0, "") }

        buildCallCount += 1

        guard buildCallCount == 1 else { return (0, "") }

        let root = request.workingDirectoryURL.path
        let canonicalRoot = root.withCString { pointer -> String in
            guard let resolved = realpath(pointer, nil) else { return root }
            defer { free(resolved) }
            return String(cString: resolved)
        }

        let reported = locations.map { location in
            "\(canonicalRoot)/\(location.fileName):\(location.line):1: error: type mismatch"
        }

        return (1, reported.joined(separator: "\n"))
    }
}
