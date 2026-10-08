import Foundation
import Testing

@testable import SwiftMutationTesting

@Suite("DerivedScheme")
struct DerivedSchemeTests {
    private let scheme = """
        <?xml version="1.0" encoding="UTF-8"?>
        <Scheme>
           <TestAction>
              <TestPlans>
                 <TestPlanReference
                    reference = "container:TestPlans/All.xctestplan">
                 </TestPlanReference>
                 <TestPlanReference
                    reference = "container:TestPlans/Unit.xctestplan"
                    default = "YES">
                 </TestPlanReference>
              </TestPlans>
              <Testables>
                 <TestableReference
                    skipped = "YES">
                    <BuildableReference
                       BlueprintName = "AppSnapshots">
                    </BuildableReference>
                 </TestableReference>
                 <TestableReference
                    skipped = "NO">
                    <BuildableReference
                       BlueprintName = "AppTests">
                    </BuildableReference>
                 </TestableReference>
              </Testables>
           </TestAction>
        </Scheme>
        """

    @Test("Given a scheme with several plans and testables, when derived, then only the plan and its testables remain")
    func keepsOnlyThePlanAndItsTestables() throws {
        let root = try FileHelpers.makeTemporaryDirectory()
        defer { FileHelpers.cleanup(root) }
        try FileManager.default.createDirectory(
            at: root.appendingPathComponent("TestPlans"), withIntermediateDirectories: true
        )
        try #"{"testTargets": [{"target": {"name": "AppTests"}}]}"#
            .write(to: root.appendingPathComponent("TestPlans/Unit.xctestplan"), atomically: true, encoding: .utf8)

        let derived = try #require(DerivedScheme.derive(scheme: scheme, plan: "Unit", root: root))

        #expect(derived.contains("TestPlans/Unit.xctestplan"))
        #expect(derived.contains("TestPlans/All.xctestplan") == false)
        #expect(derived.contains("AppTests"))
        #expect(derived.contains("AppSnapshots") == false)
    }

    @Test("Given a plan the scheme does not reference, when derived, then nothing is derived")
    func unknownPlanDerivesNothing() throws {
        let root = try FileHelpers.makeTemporaryDirectory()
        defer { FileHelpers.cleanup(root) }

        #expect(DerivedScheme.derive(scheme: scheme, plan: "Missing", root: root) == nil)
    }
}
