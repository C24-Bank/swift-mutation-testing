import Testing

@testable import SwiftMutationTesting

@Suite("StandardError")
struct StandardErrorTests {

    @Test("Given a capture, when a line is written, then the capture holds it with its newline")
    func aCaptureHoldsTheLine() {
        let written = captureErrorsSync {
            StandardError.write("Warning: something")
            StandardError.write("Error: something else")
        }

        #expect(written == "Warning: something\nError: something else\n")
    }

    @Test("Given output being captured, when an error is written, then it does not land in the output")
    func errorsAreKeptApartFromOutput() {
        let output = captureOutputSync {
            _ = captureErrorsSync { StandardError.write("Error: kept apart") }
        }

        #expect(output.isEmpty)
    }
}
