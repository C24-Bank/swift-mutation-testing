import Foundation

@testable import SwiftMutationTesting

actor CountingLauncher: ProcessLaunching {
    private let wrapped: any ProcessLaunching
    private(set) var requests: [ProcessRequest] = []

    init(wrapping wrapped: any ProcessLaunching) {
        self.wrapped = wrapped
    }

    var buildCount: Int {
        requests.filter { $0.arguments.first == "build" }.count
    }

    func launch(
        executableURL: URL,
        arguments: [String],
        workingDirectoryURL: URL,
        timeout: Double
    ) async throws -> Int32 {
        try await wrapped.launch(
            executableURL: executableURL, arguments: arguments, workingDirectoryURL: workingDirectoryURL,
            timeout: timeout
        )
    }

    func launchCapturing(
        _ request: ProcessRequest
    ) async throws -> (exitCode: Int32, output: String) {
        requests.append(request)
        return try await wrapped.launchCapturing(request)
    }
}
