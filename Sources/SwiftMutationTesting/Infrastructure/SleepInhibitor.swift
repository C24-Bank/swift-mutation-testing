import Foundation
import IOKit.pwr_mgt

enum SleepInhibitor {

    static let reason = "swift-mutation-testing run"

    static func preventingIdleSleep<T>(
        reason: String = reason,
        _ body: () async throws -> T
    ) async rethrows -> T {
        let assertion = acquire(reason: reason)
        defer { IOPMAssertionRelease(assertion) }
        return try await body()
    }

    typealias AssertionTable = () -> NSDictionary?

    static func isHeld(
        by pid: pid_t = getpid(),
        reason: String = reason,
        table: AssertionTable = assertionsByProcess
    ) -> Bool {
        let byProcess = table() ?? [:]

        return byProcess.contains { entry in
            (entry.key as? NSNumber)?.int32Value == pid && holds(reason, in: entry.value)
        }
    }

    // MARK: - Private

    private static func assertionsByProcess() -> NSDictionary? {
        var assertions: Unmanaged<CFDictionary>?
        _ = IOPMCopyAssertionsByProcess(&assertions)
        return assertions?.takeRetainedValue() as NSDictionary?
    }

    private static func acquire(reason: String) -> IOPMAssertionID {
        var id: IOPMAssertionID = 0
        _ = IOPMAssertionCreateWithName(
            kIOPMAssertionTypePreventSystemSleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            reason as CFString,
            &id
        )

        return id
    }

    private static func holds(_ reason: String, in value: Any) -> Bool {
        let held = value as? [[String: Any]] ?? []
        return held.contains { $0[kIOPMAssertionNameKey as String] as? String == reason }
    }
}
