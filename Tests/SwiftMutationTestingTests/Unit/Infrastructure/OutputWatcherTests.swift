import Foundation
import Testing

@testable import SwiftMutationTesting

@Suite("OutputWatcher")
struct OutputWatcherTests {

    @Test("Given a capture file that is not there, when asked, then no marker is reported")
    func aMissingCaptureFileReportsNoMarker() {
        var watcher = OutputWatcher(
            url: URL(fileURLWithPath: "/does/not/exist/\(UUID().uuidString)"),
            rule: .firstTestFailure
        )

        let saw = watcher.sawMarker()

        #expect(!saw)
    }

    @Test("Given output written after the last look, when asked again, then only the new bytes are scanned")
    func onlyTheNewBytesAreScanned() throws {
        let dir = try FileHelpers.makeTemporaryDirectory()
        defer { FileHelpers.cleanup(dir) }

        let file = dir.appendingPathComponent("capture.log")
        try "◇ Test aCheck() started.\n".write(to: file, atomically: true, encoding: .utf8)
        var watcher = OutputWatcher(url: file, rule: .firstTestFailure)
        let beforeTheFailure = watcher.sawMarker()

        #expect(!beforeTheFailure)

        let handle = try FileHandle(forWritingTo: file)
        try handle.seekToEnd()
        try handle.write(contentsOf: Data(#"✘ Test "aCheck()" failed after 0.1 seconds."#.utf8))
        try handle.close()

        let onTheFailure = watcher.sawMarker()
        let afterTheFailure = watcher.sawMarker()

        #expect(onTheFailure)
        #expect(!afterTheFailure)
    }
}
