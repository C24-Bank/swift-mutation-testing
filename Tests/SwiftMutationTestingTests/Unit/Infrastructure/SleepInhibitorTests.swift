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

    @Test("Given no assertion table at all, when asked, then nothing is held")
    func aMissingTableHoldsNothing() {
        #expect(!SleepInhibitor.isHeld(table: { nil }))
    }

    @Test("Given an entry for this process that is not a list of assertions, when asked, then nothing is held")
    func anEntryThatIsNotAListHoldsNothing() {
        let table: NSDictionary = [NSNumber(value: getpid()): "not a list"]

        #expect(!SleepInhibitor.isHeld(table: { table }))
    }

    @Test("Given a table naming this process with the run's reason, when asked, then it is held")
    func aTableWithTheReasonIsHeld() {
        let entry = [[kIOPMAssertionNameKey as String: SleepInhibitor.reason]]
        let table: NSDictionary = [NSNumber(value: getpid()): entry]

        #expect(SleepInhibitor.isHeld(table: { table }))
    }
}
