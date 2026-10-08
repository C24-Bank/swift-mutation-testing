import Foundation

struct OutputStopRule: Sendable, Equatable {
    let markers: [String]
    let exitCode: Int32

    func matches(_ text: String) -> Bool {
        markers.contains { text.contains($0) }
    }
}

extension OutputStopRule {
    static let firstTestFailure = OutputStopRule(markers: TestOutputParser.failureMarkers, exitCode: 1)

    /// Also stops at a crash, before xcodebuild relaunches the test runner and runs into the same crash again.
    static let firstXcodeTestFailureOrCrash = OutputStopRule(
        markers: TestOutputParser.failureMarkers + TestOutputParser.crashMarkers
            + ["Restarting after unexpected exit"],
        exitCode: 1
    )
}
