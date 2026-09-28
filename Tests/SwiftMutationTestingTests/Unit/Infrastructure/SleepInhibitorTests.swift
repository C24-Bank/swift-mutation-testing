import Foundation
import Testing

@testable import SwiftMutationTesting

@Suite("SleepInhibitor", .serialized)
struct SleepInhibitorTests {

    @Test("Given a body, when run under preventingIdleSleep, then the assertion is held only while it runs")
    func assertionIsHeldOnlyDuringBody() async {
        #expect(!SleepInhibitor.isHeld())

        let heldInside = await SleepInhibitor.preventingIdleSleep { SleepInhibitor.isHeld() }

        #expect(heldInside)
        #expect(!SleepInhibitor.isHeld())
    }

    @Test("Given a throwing body, when it throws, then the assertion is released and the error propagates")
    func assertionIsReleasedWhenBodyThrows() async {
        struct Failure: Error {}

        await #expect(throws: Failure.self) {
            try await SleepInhibitor.preventingIdleSleep { throw Failure() }
        }
        #expect(!SleepInhibitor.isHeld())
    }

    @Test("Given a body with a value, when run, then that value is returned")
    func bodyValueIsReturned() async {
        let value = await SleepInhibitor.preventingIdleSleep { 42 }
        #expect(value == 42)
    }

    @Test("Given a pid that holds nothing, when queried, then isHeld is false")
    func unrelatedProcessHoldsNothing() {
        #expect(!SleepInhibitor.isHeld(by: 1))
    }
}
