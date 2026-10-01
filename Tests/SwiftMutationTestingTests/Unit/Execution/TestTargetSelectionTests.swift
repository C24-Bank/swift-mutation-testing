import Foundation
import Testing

@testable import SwiftMutationTesting

@Suite("TestTargetSelection")
struct TestTargetSelectionTests {
    private let bundles = [URL(fileURLWithPath: "/p/CoreATests.xctest"), URL(fileURLWithPath: "/p/CoreBTests.xctest")]

    @Test("Given a target that names a bundle, when selected, then only that bundle runs, with no filter")
    func aTargetNamingABundleSelectsIt() {
        let selection = TestTargetSelection.make(target: "CoreBTests", bundleURLs: bundles)

        #expect(selection.bundleURLs == [bundles[1]])
        #expect(selection.filter == nil)
    }

    @Test("Given a target that names no bundle, when selected, then every bundle runs with the name as a filter")
    func aTargetNamingNoBundleStaysAFilter() {
        let selection = TestTargetSelection.make(target: "AdderTests", bundleURLs: bundles)

        #expect(selection.bundleURLs == bundles)
        #expect(selection.filter == "AdderTests")
    }

    @Test("Given no target, when selected, then every bundle runs unfiltered")
    func noTargetRunsEverything() {
        let selection = TestTargetSelection.make(target: nil, bundleURLs: bundles)

        #expect(selection.bundleURLs == bundles)
        #expect(selection.filter == nil)
    }
}
