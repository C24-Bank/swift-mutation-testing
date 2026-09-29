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
            schematizedFiles: [schematized],
            supportFileContent: ""
        )
        defer { try? sandbox.cleanup() }

        let content = try String(
            contentsOf: sandbox.rootURL.appendingPathComponent("File.swift"),
            encoding: .utf8
        )

        #expect(content == "schematized content")
    }

    @Test("Given support file content and Sources directory, when sandbox created, then __SMTSupport.swift is written")
    func injectsSupportFileIntoSourcesDirectory() async throws {
        let projectDir = try FileHelpers.makeTemporaryDirectory()
        defer { FileHelpers.cleanup(projectDir) }

        let sourcesDir = projectDir.appendingPathComponent("Sources")
        try FileManager.default.createDirectory(at: sourcesDir, withIntermediateDirectories: true)
        try FileHelpers.write("original content", named: "File.swift", in: sourcesDir)
        let filePath = sourcesDir.appendingPathComponent("File.swift").path

        let schematized = SchematizedFile(originalPath: filePath, schematizedContent: "schematized content")
        let sandbox = try await factory.create(
            projectPath: projectDir.path,
            schematizedFiles: [schematized],
            supportFileContent: "let support = true"
        )
        defer { try? sandbox.cleanup() }

        let supportURL = sandbox.rootURL.appendingPathComponent("Sources/__SMTSupport.swift")
        let content = try String(contentsOf: supportURL, encoding: .utf8)

        #expect(content == "let support = true")
    }

    @Test(
        "Given SPM project with target subdir, when sandbox created, then __SMTSupport.swift is in first target dir"
    )
    func injectsSupportFileIntoFirstSPMTargetDirectory() async throws {
        let projectDir = try FileHelpers.makeTemporaryDirectory()
        defer { FileHelpers.cleanup(projectDir) }

        let targetDir = projectDir.appendingPathComponent("Sources/MyLib")
        try FileManager.default.createDirectory(at: targetDir, withIntermediateDirectories: true)
        try FileHelpers.write("original content", named: "File.swift", in: targetDir)
        let filePath = targetDir.appendingPathComponent("File.swift").path

        let schematized = SchematizedFile(originalPath: filePath, schematizedContent: "schematized content")
        let sandbox = try await factory.create(
            projectPath: projectDir.path,
            schematizedFiles: [schematized],
            supportFileContent: "let support = true"
        )
        defer { try? sandbox.cleanup() }

        let supportURL = sandbox.rootURL.appendingPathComponent("Sources/MyLib/__SMTSupport.swift")
        let rootLevelURL = sandbox.rootURL.appendingPathComponent("Sources/__SMTSupport.swift")
        let content = try String(contentsOf: supportURL, encoding: .utf8)

        #expect(content == "let support = true")
        #expect(!FileManager.default.fileExists(atPath: rootLevelURL.path))
    }

    @Test(
        "Given SPM multiple targets, when sandbox created, then __SMTSupport.swift goes into first alphabetical dir"
    )
    func injectsSupportFileIntoFirstAlphabeticalSPMTargetDirectory() async throws {
        let projectDir = try FileHelpers.makeTemporaryDirectory()
        defer { FileHelpers.cleanup(projectDir) }

        let alphaDir = projectDir.appendingPathComponent("Sources/Alpha")
        let betaDir = projectDir.appendingPathComponent("Sources/Beta")
        try FileManager.default.createDirectory(at: alphaDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: betaDir, withIntermediateDirectories: true)
        try FileHelpers.write("let a = 1", named: "Alpha.swift", in: alphaDir)
        let filePath = alphaDir.appendingPathComponent("Alpha.swift").path

        let schematized = SchematizedFile(originalPath: filePath, schematizedContent: "let a = 2")
        let sandbox = try await factory.create(
            projectPath: projectDir.path,
            schematizedFiles: [schematized],
            supportFileContent: "let support = true"
        )
        defer { try? sandbox.cleanup() }

        let supportInAlpha = sandbox.rootURL.appendingPathComponent("Sources/Alpha/__SMTSupport.swift")
        let supportInBeta = sandbox.rootURL.appendingPathComponent("Sources/Beta/__SMTSupport.swift")

        #expect(FileManager.default.fileExists(atPath: supportInAlpha.path))
        #expect(!FileManager.default.fileExists(atPath: supportInBeta.path))
    }

    @Test("Given Xcode project, when sandbox created, then support content is appended to first schematized file")
    func injectsSupportContentIntoFirstSchematizedFileForXcodeProject() async throws {
        let projectDir = try FileHelpers.makeTemporaryDirectory()
        defer { FileHelpers.cleanup(projectDir) }

        try FileHelpers.write("original content", named: "File.swift", in: projectDir)
        let filePath = projectDir.appendingPathComponent("File.swift").path

        let schematized = SchematizedFile(originalPath: filePath, schematizedContent: "schematized content")
        let sandbox = try await factory.create(
            projectPath: projectDir.path,
            schematizedFiles: [schematized],
            supportFileContent: "var __swiftMutationTestingID = \"\""
        )
        defer { try? sandbox.cleanup() }

        let content = try String(
            contentsOf: sandbox.rootURL.appendingPathComponent("File.swift"),
            encoding: .utf8
        )

        #expect(content == "schematized content\nvar __swiftMutationTestingID = \"\"")
    }

    @Test(
        "Given empty support content and no Sources directory, when sandbox created, then schematized file is unchanged"
    )
    func emptySuportContentLeavesSchematizedFileUnchanged() async throws {
        let projectDir = try FileHelpers.makeTemporaryDirectory()
        defer { FileHelpers.cleanup(projectDir) }

        try FileHelpers.write("original content", named: "File.swift", in: projectDir)
        let filePath = projectDir.appendingPathComponent("File.swift").path

        let schematized = SchematizedFile(originalPath: filePath, schematizedContent: "schematized content")
        let sandbox = try await factory.create(
            projectPath: projectDir.path,
            schematizedFiles: [schematized],
            supportFileContent: ""
        )
        defer { try? sandbox.cleanup() }

        let content = try String(
            contentsOf: sandbox.rootURL.appendingPathComponent("File.swift"),
            encoding: .utf8
        )

        #expect(content == "schematized content")
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
            schematizedFiles: [],
            supportFileContent: ""
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
            schematizedFiles: [],
            supportFileContent: ""
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
            schematizedFiles: [],
            supportFileContent: ""
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
            schematizedFiles: [schematized],
            supportFileContent: ""
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

    @Test("Given computed __swiftMutationTestingID, when sandbox created, then transformed to nonisolated(unsafe) var")
    func transformsSwiftMutationTestingIDToNonisolatedUnsafe() async throws {
        let projectDir = try FileHelpers.makeTemporaryDirectory()
        defer { FileHelpers.cleanup(projectDir) }

        try FileHelpers.write("original content", named: "File.swift", in: projectDir)
        let filePath = projectDir.appendingPathComponent("File.swift").path

        let supportContent = """
            var __swiftMutationTestingID: String {
                ProcessInfo.processInfo.environment["__SWIFT_MUTATION_TESTING_ACTIVE"] ?? ""
            }
            """

        let schematized = SchematizedFile(originalPath: filePath, schematizedContent: "schematized content")
        let sandbox = try await factory.create(
            projectPath: projectDir.path,
            schematizedFiles: [schematized],
            supportFileContent: supportContent
        )
        defer { try? sandbox.cleanup() }

        let content = try String(
            contentsOf: sandbox.rootURL.appendingPathComponent("File.swift"),
            encoding: .utf8
        )

        let expected =
            "nonisolated(unsafe) var __swiftMutationTestingID: String"
            + " = ProcessInfo.processInfo.environment[\"__SWIFT_MUTATION_TESTING_ACTIVE\"] ?? \"\""
        #expect(content.contains(expected))
        #expect(!content.contains("var __swiftMutationTestingID: String {"))
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
            schematizedFiles: [],
            supportFileContent: ""
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
            schematizedFiles: [schematized],
            supportFileContent: ""
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
            schematizedFiles: [],
            supportFileContent: ""
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
            schematizedFiles: [],
            supportFileContent: ""
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
            projectPath: projectDir.path, schematizedFiles: [], supportFileContent: ""
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
            projectPath: projectDir.path, schematizedFiles: [], supportFileContent: ""
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
            schematizedFiles: [SchematizedFile(originalPath: filePath, schematizedContent: schema)],
            supportFileContent: ""
        )
        defer { try? sandbox.cleanup() }

        let written = try String(
            contentsOf: sandbox.rootURL.appendingPathComponent("File.swift"), encoding: .utf8
        )

        #expect(written == schema)
    }

    @Test("Given the first schematized file lies outside the project, when created, then no support file is written")
    func aSchematizedFileOutsideTheProjectGetsNoSupportFile() async throws {
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
            schematizedFiles: [SchematizedFile(originalPath: outside.path, schematizedContent: "let x = 2")],
            supportFileContent: "let support = true"
        )
        defer { try? sandbox.cleanup() }

        let entries = try FileManager.default.contentsOfDirectory(atPath: sandbox.rootURL.path)

        #expect(entries == ["File.swift"])
    }

    @Test(
        "Given the file the support goes into is not in the sandbox, when created, then support still lands"
    )
    func supportContentIsWrittenEvenWhenTheFileIsMissing() async throws {
        let projectDir = try FileHelpers.makeTemporaryDirectory()
        defer { FileHelpers.cleanup(projectDir) }

        try FileHelpers.write("original", named: "File.swift", in: projectDir)
        let missing = projectDir.appendingPathComponent("Ghost.swift").path

        let sandbox = try await factory.create(
            projectPath: projectDir.path,
            schematizedFiles: [SchematizedFile(originalPath: missing, schematizedContent: "let x = 2")],
            supportFileContent: "let support = true"
        )
        defer { try? sandbox.cleanup() }

        let written = try String(
            contentsOf: sandbox.rootURL.appendingPathComponent("Ghost.swift"), encoding: .utf8
        )

        #expect(written == "\nlet support = true")
    }

    @Test("Given a project where Sources is a file, when the sandbox is created, then the run fails loudly")
    func aProjectWhoseSourcesIsAFileFailsLoudly() async throws {
        let projectDir = try FileHelpers.makeTemporaryDirectory()
        defer { FileHelpers.cleanup(projectDir) }

        try FileHelpers.write("original", named: "File.swift", in: projectDir)
        try "not a directory".write(
            to: projectDir.appendingPathComponent("Sources"), atomically: true, encoding: .utf8
        )
        let filePath = projectDir.appendingPathComponent("File.swift").path

        await #expect(throws: (any Error).self) {
            _ = try await factory.create(
                projectPath: projectDir.path,
                schematizedFiles: [SchematizedFile(originalPath: filePath, schematizedContent: "mutated")],
                supportFileContent: "let support = true"
            )
        }
    }
}
