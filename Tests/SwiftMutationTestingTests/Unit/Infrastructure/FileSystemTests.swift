import Foundation
import Testing

@testable import SwiftMutationTesting

@Suite("FileSystem")
struct FileSystemTests {

    @Test("Given the project as . or as nothing, when resolved, then it is the current directory")
    func dotAndNothingAreTheCurrentDirectory() {
        var fileSystem = FileSystem()
        fileSystem.currentDirectory = { "/work/App" }

        #expect(fileSystem.projectPath(".") == "/work/App")
        #expect(fileSystem.projectPath("") == "/work/App")
    }

    @Test("Given a project path, when resolved, then it is standardized")
    func aPathIsStandardized() {
        #expect(FileSystem().projectPath("/work/App/../Other/") == "/work/Other")
    }

    @Test("Given a file and a directory, when asked, then only the directory is one")
    func onlyADirectoryIsADirectory() throws {
        let dir = try FileHelpers.makeTemporaryDirectory()
        defer { FileHelpers.cleanup(dir) }
        try FileHelpers.write("x", named: "file.txt", in: dir)
        let fileSystem = FileSystem()

        #expect(fileSystem.directoryExists(dir.path))
        #expect(!fileSystem.directoryExists(dir.appendingPathComponent("file.txt").path))
        #expect(fileSystem.fileExists(dir.appendingPathComponent("file.txt").path))
        #expect(fileSystem.contentsOfDirectory(dir.path) == ["file.txt"])
        #expect(fileSystem.contentsOfDirectory(dir.appendingPathComponent("missing").path).isEmpty)
    }

    @Test("Given a directory to create and an item to remove, when done, then the tree follows")
    func createsAndRemoves() throws {
        let dir = try FileHelpers.makeTemporaryDirectory()
        defer { FileHelpers.cleanup(dir) }
        let nested = dir.appendingPathComponent("a/b")
        let fileSystem = FileSystem()

        try fileSystem.createDirectory(nested)
        #expect(fileSystem.directoryExists(nested.path))

        fileSystem.removeItem(nested.path)
        #expect(!fileSystem.fileExists(nested.path))
    }
}
