import Testing

@testable import SwiftMutationTesting

@Suite("GateError")
struct GateErrorTests {
    @Test(
        "Given each gate error, when described, then the message names the baseline and what to do",
        arguments: [
            (GateError.baselineNotFound(path: "b.json"), "--write-baseline"),
            (.unreadableBaseline(path: "b.json"), "could not be read"),
            (.unsupportedBaselineVersion(path: "b.json", version: 9), "format version 9"),
            (
                .scopeMismatch(path: "b.json", differences: ["sources path: . → Sources"]),
                "  - sources path: . → Sources"
            ),
        ]
    )
    func describesTheProblem(error: GateError, fragment: String) {
        #expect(error.errorDescription?.contains("b.json") == true)
        #expect(error.errorDescription?.contains(fragment) == true)
    }
}
