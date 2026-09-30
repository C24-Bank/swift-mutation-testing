import Foundation
import Testing

@testable import SwiftMutationTesting

@Suite("TestBundle")
struct TestBundleTests {

    @Test("Given a bundle URL, when named, then the name is the file name without .xctest")
    func nameDropsTheExtension() {
        let url = URL(fileURLWithPath: "/s/.build/out/Products/Debug/CoreATests.xctest")

        let bundle = TestBundle(url: url, libraries: [])

        #expect(bundle.name == "CoreATests")
    }

    @Test("Given built bundles, when all are listed, then each one carries both libraries in name order")
    func allListsEveryBundleWithBothLibraries() throws {
        let dir = try FileHelpers.makeTemporaryDirectory()
        defer { FileHelpers.cleanup(dir) }
        let products = dir.appendingPathComponent(".build/out/Products/Debug")
        for name in ["CoreBTests.xctest", "CoreATests.xctest", "notes.txt"] {
            try FileManager.default.createDirectory(
                at: products.appendingPathComponent(name), withIntermediateDirectories: true
            )
        }

        let bundles = TestBundle.all(in: Sandbox(rootURL: dir))

        #expect(bundles.map(\.name) == ["CoreATests", "CoreBTests"])
        #expect(bundles.allSatisfy { $0.libraries == TestBundle.allLibraries })
    }

    @Test("Given a suite with a test target, when its bundles are asked for, then only that target's bundle is used")
    func contextPicksTheSuitesOwnBundle() {
        let context = makeContext(bundles: ["CoreATests", "CoreBTests"])

        let own = context.bundles(declaring: TargetedSuite(name: "AdderTests", testTarget: "CoreBTests"))

        #expect(own.map(\.name) == ["CoreBTests"])
    }

    @Test(
        "Given a suite without a known bundle, when its bundles are asked for, then every bundle is used",
        arguments: [nil, "Elsewhere"]
    )
    func contextFallsBackToEveryBundle(testTarget: String?) {
        let context = makeContext(bundles: ["CoreATests", "CoreBTests"])

        let all = context.bundles(declaring: TargetedSuite(name: "AdderTests", testTarget: testTarget))

        #expect(all.map(\.name) == ["CoreATests", "CoreBTests"])
    }

    private func makeContext(bundles: [String]) -> TestExecutionContext {
        TestExecutionContext(
            artifact: BuildArtifact(derivedDataPath: "/s/.build", xctestrunURL: nil, plist: nil),
            sandbox: Sandbox(rootURL: URL(fileURLWithPath: "/s")),
            pool: makeSimulatorPool(launcher: MockProcessLauncher(exitCode: 0)),
            configuration: makeRunnerConfiguration(projectType: .spm),
            bundles: bundles.map {
                TestBundle(url: URL(fileURLWithPath: "/s/.build/out/Products/Debug/\($0).xctest"), libraries: [])
            }
        )
    }
}
