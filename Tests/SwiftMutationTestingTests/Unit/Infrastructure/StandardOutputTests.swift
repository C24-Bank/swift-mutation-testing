import Foundation
import Testing

@testable import SwiftMutationTesting

@Suite("StandardOutput")
struct StandardOutputTests {

    @Test("Given a capture, when lines are written, then each one is collected on its own line")
    func captureCollectsWrittenLines() {
        let capture = StandardOutput.Capture()

        StandardOutput.$capture.withValue(capture) {
            StandardOutput.write("first")
            StandardOutput.write()
            StandardOutput.write("second")
        }

        #expect(capture.contents == "first\n\nsecond\n")
    }

    @Test("Given a capture, when a child task writes, then the capture collects it")
    func childTasksWriteIntoTheCapture() async {
        let capture = StandardOutput.Capture()

        await StandardOutput.$capture.withValue(capture) {
            await withTaskGroup(of: Void.self) { group in
                group.addTask { StandardOutput.write("from a child") }
            }
        }

        #expect(capture.contents == "from a child\n")
    }

    @Test("Given two captures running at once, when each writes, then neither sees the other's output")
    func concurrentCapturesStayApart() async {
        async let first = captureOutput {
            for _ in 0 ..< 100 { StandardOutput.write("a") }
        }
        async let second = captureOutput {
            for _ in 0 ..< 100 { StandardOutput.write("b") }
        }

        let (a, b) = await (first, second)

        #expect(a == String(repeating: "a\n", count: 100))
        #expect(b == String(repeating: "b\n", count: 100))
    }
}
