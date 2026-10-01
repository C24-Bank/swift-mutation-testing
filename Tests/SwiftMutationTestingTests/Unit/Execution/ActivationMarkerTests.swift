import Foundation
import Testing

@testable import SwiftMutationTesting

@Suite("ActivationMarker")
struct ActivationMarkerTests {

    @Test("Given a sandbox, when a marker is made, then it lives in the sandbox's activation directory")
    func markerLivesInTheActivationDirectory() throws {
        let dir = try FileHelpers.makeTemporaryDirectory()
        defer { FileHelpers.cleanup(dir) }

        let marker = ActivationMarker(for: "swift-mutation-testing_3", in: Sandbox(rootURL: dir))

        let directory = dir.appendingPathComponent(ActivationMarker.directoryName)
        #expect(marker.path.hasPrefix(directory.path + "/swift-mutation-testing_3-"))
        #expect(FileManager.default.fileExists(atPath: directory.path))
    }

    @Test("Given two markers for one mutant, when made, then their paths differ")
    func markersOfTheSameMutantDiffer() throws {
        let dir = try FileHelpers.makeTemporaryDirectory()
        defer { FileHelpers.cleanup(dir) }
        let sandbox = Sandbox(rootURL: dir)

        #expect(ActivationMarker(for: "m0", in: sandbox).path != ActivationMarker(for: "m0", in: sandbox).path)
    }

    @Test("Given nothing wrote the marker, when read, then it was not written")
    func anUnwrittenMarkerReadsFalse() throws {
        let dir = try FileHelpers.makeTemporaryDirectory()
        defer { FileHelpers.cleanup(dir) }

        #expect(!ActivationMarker(for: "m0", in: Sandbox(rootURL: dir)).wasWritten())
    }

    @Test("Given the test process wrote the marker, when read, then it was written and the file is removed")
    func aWrittenMarkerReadsTrueOnce() throws {
        let dir = try FileHelpers.makeTemporaryDirectory()
        defer { FileHelpers.cleanup(dir) }
        let marker = ActivationMarker(for: "m0", in: Sandbox(rootURL: dir))
        FileManager.default.createFile(atPath: marker.path, contents: nil)

        #expect(marker.wasWritten())
        #expect(!FileManager.default.fileExists(atPath: marker.path))
        #expect(!marker.wasWritten())
    }
}
