import Foundation

@testable import SwiftMutationTesting

actor WarmSandboxLauncher: ProcessLaunching {
    private let failsWarmBuildsAfterTheFirstRoot: Bool
    private let failsEveryBuild: Bool
    private var roots: [String] = []
    private var brokenRoots: Set<String> = []
    private var inFlightBuilds = 0
    private(set) var maxInFlightBuilds = 0
    private(set) var testRunsByRoot: [String: Int] = [:]

    init(failsWarmBuildsAfterTheFirstRoot: Bool = false, failsEveryBuild: Bool = false) {
        self.failsWarmBuildsAfterTheFirstRoot = failsWarmBuildsAfterTheFirstRoot
        self.failsEveryBuild = failsEveryBuild
    }

    var buildRoots: [String] { roots }

    func launch(
        executableURL: URL,
        arguments: [String],
        workingDirectoryURL: URL,
        timeout: Double
    ) async throws -> Int32 {
        0
    }

    func launchCapturing(
        _ request: ProcessRequest
    ) async throws -> (exitCode: Int32, output: String) {
        request.recordActivation()
        let root = request.workingDirectoryURL.path

        if request.arguments.first == "build" {
            let isWarmBuild = !roots.contains(root)
            if isWarmBuild { roots.append(root) }

            if failsEveryBuild || (failsWarmBuildsAfterTheFirstRoot && isWarmBuild && roots.count > 1) {
                brokenRoots.insert(root)
            }

            inFlightBuilds += 1
            maxInFlightBuilds = max(maxInFlightBuilds, inFlightBuilds)
            try await Task.sleep(for: .milliseconds(30))
            inFlightBuilds -= 1

            return brokenRoots.contains(root) ? (1, "error: warm build broke in \(root)") : (0, "")
        }

        if request.arguments.first == "test" || request.arguments.first == "xctest"
            || request.executableURL.lastPathComponent == "swiftpm-testing-helper"
        {
            testRunsByRoot[root, default: 0] += 1
        }

        return (0, "")
    }
}
