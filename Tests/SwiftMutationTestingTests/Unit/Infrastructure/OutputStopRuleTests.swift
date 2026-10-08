import Testing

@testable import SwiftMutationTesting

@Suite("OutputStopRule")
struct OutputStopRuleTests {
    private let rule = OutputStopRule.firstXcodeTestFailureOrCrash

    @Test(
        "Given a failing test or a crash in xcodebuild output, when matched, then the Xcode rule stops the run",
        arguments: [
            "Test Case '-[C24_MockedTests.AppUpdatePageViewModelTests testSubtitle]' failed (0.012 seconds).",
            "✘ Test fetchReEmitsWhenDataChanges() recorded an issue at CashflowManagerTests.swift:129:36: Issue recorded",
            "✘ Test fetchReEmitsWhenDataChanges() failed after 6.040 seconds with 4 issues.",
            "Swift/ContiguousArrayBuffer.swift:691: Fatal error: Index out of range",
            "Restarting after unexpected exit, crash, or test timeout; summary will include totals from previous launches.",
        ]
    )
    func stopsOnFailureOrCrash(line: String) {
        #expect(rule.matches(line))
        #expect(rule.exitCode == 1)
    }

    @Test(
        "Given passing or neutral xcodebuild output, when matched, then the Xcode rule lets the run go on",
        arguments: [
            "Test Case '-[C24_MockedTests.AppUpdatePageViewModelTests testSubtitle]' passed (0.012 seconds).",
            "✔ Test fetchReEmitsWhenDataChanges() passed after 0.003 seconds.",
            "◇ Test fetchReEmitsWhenDataChanges() started.",
            "Test Suite 'All tests' started at 2026-10-08 12:00:00.000.",
        ]
    )
    func goesOnForPassingOutput(line: String) {
        #expect(rule.matches(line) == false)
    }
}
