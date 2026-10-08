import Foundation

struct BuildStage: Sendable {
    let launcher: any ProcessLaunching

    func build(
        sandbox: Sandbox,
        scheme: String,
        destination: String,
        timeout: Double
    ) async throws -> BuildArtifact {
        let derivedDataURL = sandbox.derivedDataURL
        let scheme = DerivedScheme.prepare(in: sandbox.rootURL, scheme: scheme)

        var arguments = [
            "build-for-testing",
            "-scheme", scheme,
            "-destination", destination,
            "-derivedDataPath", derivedDataURL.path,
        ]

        if let testPlan = ProcessInfo.processInfo.environment["SMT_TEST_PLAN"], !testPlan.isEmpty {
            arguments += ["-testPlan", testPlan]
        }

        if let workspaceURL = findXcworkspace(in: sandbox.rootURL) {
            arguments += ["-workspace", workspaceURL.path]
        } else if let projectURL = findXcodeproj(in: sandbox.rootURL) {
            arguments += ["-project", projectURL.path]
        }

        let (exitCode, buildOutput) = try await launcher.launchCapturing(
            ProcessRequest(
                executableURL: URL(fileURLWithPath: "/usr/bin/xcodebuild"),
                arguments: arguments,
                environment: nil,
                additionalEnvironment: [:],
                workingDirectoryURL: sandbox.rootURL,
                timeout: timeout
            )
        )

        guard exitCode != SPMResultParser.timedOutExitCode else {
            throw BuildError.timedOut(seconds: timeout, output: buildOutput)
        }

        guard exitCode == 0 else {
            throw BuildError.compilationFailed(output: buildOutput)
        }

        let productsURLs = [
            derivedDataURL.appendingPathComponent("Build/Products"),
            sandbox.rootURL.appendingPathComponent("DerivedData/Build/Products"),
        ]

        guard let xctestrunURL = productsURLs.lazy.compactMap({ findXctestrun(in: $0) }).first else {
            throw BuildError.xctestrunNotFound
        }

        let data = try Data(contentsOf: xctestrunURL)

        guard let plist = XCTestRunPlist(data) else {
            throw BuildError.xctestrunNotFound
        }

        return BuildArtifact(
            derivedDataPath: derivedDataURL.path,
            xctestrunURL: xctestrunURL,
            plist: plist
        )
    }

    func buildSPM(
        sandbox: Sandbox,
        timeout: Double
    ) async throws -> BuildArtifact {
        let arguments = ["build", "--build-tests"]

        let (exitCode, buildOutput) = try await launcher.launchCapturing(
            ProcessRequest(
                executableURL: URL(fileURLWithPath: "/usr/bin/swift"),
                arguments: arguments,
                environment: nil,
                additionalEnvironment: [:],
                workingDirectoryURL: sandbox.rootURL,
                timeout: timeout
            )
        )

        guard exitCode != SPMResultParser.timedOutExitCode else {
            throw BuildError.timedOut(seconds: timeout, output: buildOutput)
        }

        guard exitCode == 0 else { throw BuildError.compilationFailed(output: buildOutput) }

        return BuildArtifact(
            derivedDataPath: sandbox.rootURL.appendingPathComponent(".build").path,
            xctestrunURL: nil,
            plist: nil
        )
    }

    private func findXcworkspace(in directory: URL) -> URL? {
        let items =
            (try? FileManager.default.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: nil
            )) ?? []
        return items.first { $0.pathExtension == "xcworkspace" }
    }

    private func findXcodeproj(in directory: URL) -> URL? {
        let items =
            (try? FileManager.default.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: nil
            )) ?? []
        return items.first { $0.pathExtension == "xcodeproj" }
    }

    private func findXctestrun(in directory: URL) -> URL? {
        let items =
            (try? FileManager.default.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: nil
            )) ?? []
        let candidates = items.filter { $0.pathExtension == "xctestrun" }
        if let testPlan = ProcessInfo.processInfo.environment["SMT_TEST_PLAN"], !testPlan.isEmpty {
            return candidates.first { $0.lastPathComponent.contains("_\(testPlan)_") }
        }
        return candidates.max { lhs, rhs in
            let lhsDate = (try? lhs.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
            let rhsDate = (try? rhs.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
            return (lhsDate ?? .distantPast) < (rhsDate ?? .distantPast)
        }
    }
}
