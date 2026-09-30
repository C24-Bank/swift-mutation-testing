@testable import SwiftMutationTesting

func captureOutput(_ block: () async -> Void) async -> String {
    let capture = StandardOutput.Capture()
    await StandardOutput.$capture.withValue(capture) {
        await block()
    }
    return capture.contents
}

func captureOutputSync(_ block: () -> Void) -> String {
    let capture = StandardOutput.Capture()
    StandardOutput.$capture.withValue(capture) {
        block()
    }
    return capture.contents
}
