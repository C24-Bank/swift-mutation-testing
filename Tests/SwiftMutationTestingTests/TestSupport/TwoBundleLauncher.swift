import Foundation

@testable import SwiftMutationTesting

actor TwoBundleLauncher: ProcessLaunching {
    struct Run: Equatable {
        let bundle: String
        let filter: String?
        let mutantID: String
    }

    static let bundles = ["CoreATests", "CoreBTests"]

    private let killers: [String: String]
    private let noTestsIn: Set<String>
    private let baselineFailsIn: Set<String>
    private(set) var runs: [Run] = []

    init(killers: [String: String] = [:], noTestsIn: Set<String> = [], baselineFailsIn: Set<String> = []) {
        self.killers = killers
        self.noTestsIn = noTestsIn
        self.baselineFailsIn = baselineFailsIn
    }

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
        if request.arguments.first == "build" {
            for bundle in Self.bundles {
                let macOS = request.workingDirectoryURL
                    .appendingPathComponent(".build/out/Products/Debug/\(bundle).xctest/Contents/MacOS")
                try FileManager.default.createDirectory(at: macOS, withIntermediateDirectories: true)
                FileManager.default.createFile(atPath: macOS.appendingPathComponent(bundle).path, contents: Data())
            }
            return (0, "")
        }

        if request.arguments.first == "xctest" {
            return (TestBundleInvocation.noTestsExitCode, "")
        }

        guard request.executableURL.lastPathComponent == "swiftpm-testing-helper" else { return (0, "") }

        let bundle = bundleName(of: request)
        let mutantID = request.additionalEnvironment["__SWIFT_MUTATION_TESTING_ACTIVE"] ?? ""

        if noTestsIn.contains(bundle) {
            return (TestBundleInvocation.noTestsExitCode, "")
        }

        if mutantID.isEmpty {
            return baselineFailsIn.contains(bundle)
                ? (1, #"✘ Test "broken" failed after 0.001 seconds with 1 issue."#)
                : (0, "✔ Test run with 2 tests in 1 suite passed after 0.1 seconds.")
        }

        let filter = request.arguments.firstIndex(of: "--filter").map { request.arguments[$0 + 1] }
        runs.append(Run(bundle: bundle, filter: filter, mutantID: mutantID))

        if let test = killers[bundle] {
            return (1, "✘ Test \"\(test)\" failed after 0.001 seconds with 1 issue.")
        }
        return (0, "✔ Test run with 2 tests in 1 suite passed after 0.1 seconds.")
    }

    private func bundleName(of request: ProcessRequest) -> String {
        let path = request.arguments.firstIndex(of: "--test-bundle-path").map { request.arguments[$0 + 1] } ?? ""
        let component = URL(fileURLWithPath: path).pathComponents.first { $0.hasSuffix(".xctest") } ?? ""
        return String(component.dropLast(".xctest".count))
    }
}
