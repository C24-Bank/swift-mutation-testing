import Foundation
import Testing

@testable import SwiftMutationTesting

@Suite("SandboxFactory")
struct SandboxFactoryTests {
    private let factory = SandboxFactory()

    @Test("Given schematized files, when sandbox created, then schematized content is written to sandbox")
    func writesSchematizedContent() async throws {
        let projectDir = try FileHelpers.makeTemporaryDirectory()
        defer { FileHelpers.cleanup(projectDir) }

        try FileHelpers.write("original content", named: "File.swift", in: projectDir)
        let filePath = projectDir.appendingPathComponent("File.swift").path

        let schematized = SchematizedFile(originalPath: filePath, schematizedContent: "schematized content")
        let sandbox = try await factory.create(
            projectPath: projectDir.path,
            schematizedFiles: [schematized]
        )
        defer { try? sandbox.cleanup() }

        let content = try String(
            contentsOf: sandbox.rootURL.appendingPathComponent("File.swift"),
            encoding: .utf8
        )

        #expect(content == "schematized content")
    }

    @Test("Given a project, when sandbox created, then it lives in the sandbox directory, not loose in temp")
    func createsSandboxInsideSandboxDirectory() async throws {
        let projectDir = try FileHelpers.makeTemporaryDirectory()
        defer { FileHelpers.cleanup(projectDir) }
        try FileHelpers.write("let x = 1", named: "Main.swift", in: projectDir)

        let sandbox = try await factory.createClean(projectPath: projectDir.path)
        defer { try? sandbox.cleanup() }

        #expect(
            sandbox.rootURL.deletingLastPathComponent().standardizedFileURL
                == SandboxName.directory.standardizedFileURL
        )
    }

    @Test("Given xcodeproj directory, when sandbox created, then xcuserdata is empty directory not a symlink")
    func xcodeprojXcuserdataIsEmptyDirectory() async throws {
        let projectDir = try FileHelpers.makeTemporaryDirectory()
        defer { FileHelpers.cleanup(projectDir) }

        let xcuserdataDir =
            projectDir
            .appendingPathComponent("App.xcodeproj/xcuserdata")
        try FileManager.default.createDirectory(at: xcuserdataDir, withIntermediateDirectories: true)
        try FileHelpers.write("user data", named: "user.xcuserdatad", in: xcuserdataDir)

        let sandbox = try await factory.create(
            projectPath: projectDir.path,
            schematizedFiles: []
        )
        defer { try? sandbox.cleanup() }

        let sandboxXcuserdata = sandbox.rootURL.appendingPathComponent("App.xcodeproj/xcuserdata")
        let isSymlink = (try? sandboxXcuserdata.resourceValues(forKeys: [.isSymbolicLinkKey]))?.isSymbolicLink ?? false
        let userDataFile = sandboxXcuserdata.appendingPathComponent("user.xcuserdatad")

        var isDir: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: sandboxXcuserdata.path, isDirectory: &isDir)

        #expect(exists)
        #expect(isDir.boolValue)
        #expect(!isSymlink)
        #expect(!FileManager.default.fileExists(atPath: userDataFile.path))
    }

    @Test("Given file not in schematized list, when sandbox created, then file is a symlink to the original")
    func nonSchematizedFileIsSymlink() async throws {
        let projectDir = try FileHelpers.makeTemporaryDirectory()
        defer { FileHelpers.cleanup(projectDir) }

        try FileHelpers.write("original content", named: "Unchanged.swift", in: projectDir)

        let sandbox = try await factory.create(
            projectPath: projectDir.path,
            schematizedFiles: []
        )
        defer { try? sandbox.cleanup() }

        let sandboxFile = sandbox.rootURL.appendingPathComponent("Unchanged.swift")
        let isSymlink = (try? sandboxFile.resourceValues(forKeys: [.isSymbolicLinkKey]))?.isSymbolicLink ?? false
        let content = try String(contentsOf: sandboxFile, encoding: .utf8)

        #expect(isSymlink)
        #expect(content == "original content")
    }

    @Test("Given mutated file path and content, when single-file sandbox created, then mutated content is written")
    func writesMutatedContentInSingleFileSandbox() async throws {
        let projectDir = try FileHelpers.makeTemporaryDirectory()
        defer { FileHelpers.cleanup(projectDir) }

        try FileHelpers.write("original content", named: "File.swift", in: projectDir)
        let filePath = projectDir.appendingPathComponent("File.swift").path

        let sandbox = try await factory.create(
            projectPath: projectDir.path,
            mutatedFilePath: filePath,
            mutatedContent: "mutated content"
        )
        defer { try? sandbox.cleanup() }

        let content = try String(
            contentsOf: sandbox.rootURL.appendingPathComponent("File.swift"),
            encoding: .utf8
        )

        #expect(content == "mutated content")
    }

    @Test("Given xcodeproj with swiftlint build phase, when sandbox created, then shellScript is replaced with exit 0")
    func disablesSwiftLintBuildPhase() async throws {
        let projectDir = try FileHelpers.makeTemporaryDirectory()
        defer { FileHelpers.cleanup(projectDir) }

        let xcodeprojDir = projectDir.appendingPathComponent("App.xcodeproj")
        try FileManager.default.createDirectory(at: xcodeprojDir, withIntermediateDirectories: true)
        try swiftLintPbxprojContent().write(
            to: xcodeprojDir.appendingPathComponent("project.pbxproj"),
            atomically: true,
            encoding: .utf8
        )

        let sandbox = try await factory.create(
            projectPath: projectDir.path,
            schematizedFiles: []
        )
        defer { try? sandbox.cleanup() }

        let sandboxPbxproj = sandbox.rootURL
            .appendingPathComponent("App.xcodeproj/project.pbxproj")
        let data = try Data(contentsOf: sandboxPbxproj)
        var format = PropertyListSerialization.PropertyListFormat.xml
        let plist =
            try PropertyListSerialization.propertyList(
                from: data, options: [], format: &format
            ) as? [String: Any]
        let objects = plist?["objects"] as? [String: Any]
        let lintPhase = objects?["AABBCC"] as? [String: Any]
        let otherPhase = objects?["DDEEFF"] as? [String: Any]

        #expect(lintPhase?["shellScript"] as? String == "exit 0\n")
        #expect(otherPhase?["shellScript"] as? String == "echo hello")
    }

    @Test("Given empty switch case bodies in schematized content, when sandbox created, then break is inserted")
    func insertsBreakIntoEmptySwitchCaseBodies() async throws {
        let projectDir = try FileHelpers.makeTemporaryDirectory()
        defer { FileHelpers.cleanup(projectDir) }

        try FileHelpers.write("original content", named: "File.swift", in: projectDir)
        let filePath = projectDir.appendingPathComponent("File.swift").path

        let schematizedContent = """
            switch __swiftMutationTestingID {
            case "abc-123":
            case "def-456":
                foo()
            default:
                bar()
            }
            """

        let schematized = SchematizedFile(originalPath: filePath, schematizedContent: schematizedContent)
        let sandbox = try await factory.create(
            projectPath: projectDir.path,
            schematizedFiles: [schematized]
        )
        defer { try? sandbox.cleanup() }

        let content = try String(
            contentsOf: sandbox.rootURL.appendingPathComponent("File.swift"),
            encoding: .utf8
        )

        let expectedContent = """
            switch __swiftMutationTestingID {
            case "abc-123":
                break
            case "def-456":
                foo()
            default:
                bar()
            }
            """

        #expect(content == expectedContent)
    }

    @Test("Given xcworkspace with xcshareddata file, when sandbox created, then xcshareddata file is copied")
    func xcworkspaceXcsharedDataFileIsCopied() async throws {
        let projectDir = try FileHelpers.makeTemporaryDirectory()
        defer { FileHelpers.cleanup(projectDir) }

        let xcshareddataDir =
            projectDir
            .appendingPathComponent("App.xcworkspace/xcshareddata")
        try FileManager.default.createDirectory(at: xcshareddataDir, withIntermediateDirectories: true)
        try "shared content".write(
            to: xcshareddataDir.appendingPathComponent("scheme.xcscheme"),
            atomically: true, encoding: .utf8
        )

        let sandbox = try await factory.create(
            projectPath: projectDir.path,
            schematizedFiles: []
        )
        defer { try? sandbox.cleanup() }

        let sandboxFile = sandbox.rootURL
            .appendingPathComponent("App.xcworkspace/xcshareddata/scheme.xcscheme")
        let isSymlink = (try? sandboxFile.resourceValues(forKeys: [.isSymbolicLinkKey]))?.isSymbolicLink ?? false
        #expect(!isSymlink)
        let content = try String(contentsOf: sandboxFile, encoding: .utf8)
        #expect(content == "shared content")
    }

    @Test("Given empty switch case body preceded by blank line, when sandbox created, then break is inserted")
    func insertsBreakWhenEmptyCaseBodyHasBlankLineBefore() async throws {
        let projectDir = try FileHelpers.makeTemporaryDirectory()
        defer { FileHelpers.cleanup(projectDir) }

        try FileHelpers.write("original content", named: "File.swift", in: projectDir)
        let filePath = projectDir.appendingPathComponent("File.swift").path

        let schematizedContent = """
            switch __swiftMutationTestingID {
            case "abc-123":

            case "def-456":
                foo()
            default:
                bar()
            }
            """

        let schematized = SchematizedFile(originalPath: filePath, schematizedContent: schematizedContent)
        let sandbox = try await factory.create(
            projectPath: projectDir.path,
            schematizedFiles: [schematized]
        )
        defer { try? sandbox.cleanup() }

        let content = try String(
            contentsOf: sandbox.rootURL.appendingPathComponent("File.swift"),
            encoding: .utf8
        )

        #expect(content.contains("    break"))
        #expect(content.contains("case \"abc-123\":"))
    }

    @Test("Given build output directories, when sandbox created, then they are not replicated")
    func skipsBuildOutputDirectories() async throws {
        let projectDir = try FileHelpers.makeTemporaryDirectory()
        defer { FileHelpers.cleanup(projectDir) }

        try FileHelpers.write("let kept = true", named: "File.swift", in: projectDir)

        for skipped in [".build", "DerivedData", ".xmr-cache"] {
            let directory = projectDir.appendingPathComponent(skipped)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try FileHelpers.write("stale", named: "artifact.o", in: directory)
        }

        let sandbox = try await factory.create(
            projectPath: projectDir.path,
            schematizedFiles: []
        )
        defer { try? sandbox.cleanup() }

        for skipped in [".build", "DerivedData", ".xmr-cache"] {
            #expect(
                !FileManager.default.fileExists(atPath: sandbox.rootURL.appendingPathComponent(skipped).path),
                "\(skipped) should not be replicated into the sandbox"
            )
        }
        #expect(FileManager.default.fileExists(atPath: sandbox.rootURL.appendingPathComponent("File.swift").path))
    }

    @Test("Given created sandbox, when cleanup called, then sandbox directory no longer exists")
    func cleanupRemovesSandboxDirectory() async throws {
        let projectDir = try FileHelpers.makeTemporaryDirectory()
        defer { FileHelpers.cleanup(projectDir) }

        let sandbox = try await factory.create(
            projectPath: projectDir.path,
            schematizedFiles: []
        )

        try sandbox.cleanup()

        #expect(!FileManager.default.fileExists(atPath: sandbox.rootURL.path))
    }

    @Test("Given a pbxproj that is not a property list, when the sandbox is created, then it is left as it is")
    func aPbxprojThatIsNotAPropertyListIsLeftAlone() async throws {
        let projectDir = try FileHelpers.makeTemporaryDirectory()
        defer { FileHelpers.cleanup(projectDir) }

        let xcodeproj = projectDir.appendingPathComponent("App.xcodeproj")
        try FileManager.default.createDirectory(at: xcodeproj, withIntermediateDirectories: true)
        try "this is not a plist".write(
            to: xcodeproj.appendingPathComponent("project.pbxproj"), atomically: true, encoding: .utf8
        )

        let sandbox = try await factory.create(
            projectPath: projectDir.path, schematizedFiles: []
        )
        defer { try? sandbox.cleanup() }

        let copied = try String(
            contentsOf: sandbox.rootURL.appendingPathComponent("App.xcodeproj/project.pbxproj"), encoding: .utf8
        )

        #expect(copied == "this is not a plist")
    }

    @Test("Given a pbxproj with no objects, when the sandbox is created, then it is left as it is")
    func aPbxprojWithoutObjectsIsLeftAlone() async throws {
        let projectDir = try FileHelpers.makeTemporaryDirectory()
        defer { FileHelpers.cleanup(projectDir) }

        let xcodeproj = projectDir.appendingPathComponent("App.xcodeproj")
        try FileManager.default.createDirectory(at: xcodeproj, withIntermediateDirectories: true)
        let plist = """
            <?xml version="1.0" encoding="UTF-8"?>
            <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
            <plist version="1.0">
            <dict>
                <key>archiveVersion</key>
                <string>1</string>
            </dict>
            </plist>
            """
        try plist.write(
            to: xcodeproj.appendingPathComponent("project.pbxproj"), atomically: true, encoding: .utf8
        )

        let sandbox = try await factory.create(
            projectPath: projectDir.path, schematizedFiles: []
        )
        defer { try? sandbox.cleanup() }

        let copied = try String(
            contentsOf: sandbox.rootURL.appendingPathComponent("App.xcodeproj/project.pbxproj"), encoding: .utf8
        )

        #expect(copied.contains("archiveVersion"))
        #expect(!copied.contains("exit 0"))
    }

    @Test("Given a schema whose last line opens a case, when the sandbox is created, then nothing is appended to it")
    func aSchemaEndingInACaseIsWrittenAsItIs() async throws {
        let projectDir = try FileHelpers.makeTemporaryDirectory()
        defer { FileHelpers.cleanup(projectDir) }

        try FileHelpers.write("original", named: "File.swift", in: projectDir)
        let filePath = projectDir.appendingPathComponent("File.swift").path
        let schema = "switch id {\ncase \"swift-mutation-testing_0\":"

        let sandbox = try await factory.create(
            projectPath: projectDir.path,
            schematizedFiles: [SchematizedFile(originalPath: filePath, schematizedContent: schema)]
        )
        defer { try? sandbox.cleanup() }

        let written = try String(
            contentsOf: sandbox.rootURL.appendingPathComponent("File.swift"), encoding: .utf8
        )

        #expect(written == schema)
    }

    @Test("Given the first schematized file lies outside the project, when created, then it is not written")
    func aSchematizedFileOutsideTheProjectIsNotWritten() async throws {
        let projectDir = try FileHelpers.makeTemporaryDirectory()
        let elsewhere = try FileHelpers.makeTemporaryDirectory()
        defer {
            FileHelpers.cleanup(projectDir)
            FileHelpers.cleanup(elsewhere)
        }

        try FileHelpers.write("original", named: "File.swift", in: projectDir)
        let outside = elsewhere.appendingPathComponent("Outside.swift")
        try "let x = 1".write(to: outside, atomically: true, encoding: .utf8)

        let sandbox = try await factory.create(
            projectPath: projectDir.path,
            schematizedFiles: [SchematizedFile(originalPath: outside.path, schematizedContent: "let x = 2")]
        )
        defer { try? sandbox.cleanup() }

        let entries = try FileManager.default.contentsOfDirectory(atPath: sandbox.rootURL.path)

        #expect(entries == ["File.swift"])
    }

}
