import Foundation
import Testing

@testable import SwiftMutationTesting

@Suite("ConfigurationResolver Xcode container")
struct ConfigurationResolverContainerTests {
    private let resolver = ConfigurationResolver()

    @Test("Given --workspace, when resolved, then the container is that workspace")
    func theWorkspaceFlag() throws {
        let root = try XcodeContainerLocatorTests.root(["App.xcworkspace", "Tools.xcworkspace"])
        defer { FileHelpers.cleanup(root) }

        let result = try resolver.resolve(
            cliArguments: Self.arguments(root, workspace: "App.xcworkspace"), fileValues: [:]
        )

        #expect(result.build.xcodeContainer == .workspace("App.xcworkspace"))
    }

    @Test("Given the project key in the file, when resolved, then the container is that project")
    func theProjectKey() throws {
        let root = try XcodeContainerLocatorTests.root(["A.xcodeproj", "B.xcodeproj"])
        defer { FileHelpers.cleanup(root) }

        let result = try resolver.resolve(cliArguments: Self.arguments(root), fileValues: ["project": "B.xcodeproj"])

        #expect(result.build.xcodeContainer == .project("B.xcodeproj"))
    }

    @Test(
        "Given --project on the command line and a workspace key in the file, when resolved, then the command line wins"
    )
    func theCommandLineWinsAsAWhole() throws {
        let root = try XcodeContainerLocatorTests.root(["App.xcworkspace", "A.xcodeproj"])
        defer { FileHelpers.cleanup(root) }

        let result = try resolver.resolve(
            cliArguments: Self.arguments(root, project: "A.xcodeproj"), fileValues: ["workspace": "App.xcworkspace"]
        )

        #expect(result.build.xcodeContainer == .project("A.xcodeproj"))
    }

    @Test("Given no container and one workspace at the root, when resolved, then it is located")
    func automatic() throws {
        let root = try XcodeContainerLocatorTests.root(["App.xcworkspace", "App.xcodeproj"])
        defer { FileHelpers.cleanup(root) }

        let result = try resolver.resolve(cliArguments: Self.arguments(root), fileValues: [:])

        #expect(result.build.xcodeContainer == .workspace("App.xcworkspace"))
    }

    @Test("Given two workspaces and no container, when resolved, then the run is refused before anything is built")
    func ambiguityRefusesTheRun() throws {
        let root = try XcodeContainerLocatorTests.root(["App.xcworkspace", "Tools.xcworkspace"])
        defer { FileHelpers.cleanup(root) }

        #expect(throws: UsageError.self) { try resolver.resolve(cliArguments: Self.arguments(root), fileValues: [:]) }
    }

    @Test("Given both keys in the file, when resolved, then it is a usage error")
    func bothKeysAreRefused() throws {
        let root = try XcodeContainerLocatorTests.root(["App.xcworkspace", "A.xcodeproj"])
        defer { FileHelpers.cleanup(root) }

        #expect(throws: UsageError(message: "--workspace and --project cannot be used together; give one container")) {
            try resolver.resolve(
                cliArguments: Self.arguments(root),
                fileValues: ["workspace": "App.xcworkspace", "project": "A.xcodeproj"]
            )
        }
    }

    @Test("Given a package, when resolved, then there is no container; naming one makes it an Xcode run")
    func packagesHaveNone() throws {
        let root = try XcodeContainerLocatorTests.root(["App.xcodeproj"])
        defer { FileHelpers.cleanup(root) }
        try "// swift-tools-version: 5.9".write(
            to: root.appendingPathComponent("Package.swift"), atomically: true, encoding: .utf8
        )

        let package = try resolver.resolve(
            cliArguments: ParsedArguments(projectPath: root.path), fileValues: [:]
        )
        #expect(package.build.projectType == .spm)
        #expect(package.build.xcodeContainer == nil)

        #expect(throws: UsageError(message: "--scheme is required")) {
            try resolver.resolve(
                cliArguments: ParsedArguments(projectPath: root.path, build: .init(xcodeProject: "App.xcodeproj")),
                fileValues: [:]
            )
        }
    }

    static func arguments(_ root: URL, workspace: String? = nil, project: String? = nil) -> ParsedArguments {
        ParsedArguments(
            projectPath: root.path,
            build: .init(scheme: "App", destination: "platform=macOS", workspace: workspace, xcodeProject: project)
        )
    }
}
