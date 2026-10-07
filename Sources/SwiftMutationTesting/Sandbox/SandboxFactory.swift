import Foundation

struct SandboxFactory: Sendable {
    static var inPlace: Bool {
        ProcessInfo.processInfo.environment["SMT_IN_PLACE"] == "1"
    }

    func create(
        projectPath: String,
        schematizedFiles: [SchematizedFile],
        supportFileContent: String
    ) async throws -> Sandbox {
        if Self.inPlace {
            return try createInPlace(
                projectPath: projectPath,
                schematizedFiles: schematizedFiles,
                supportFileContent: supportFileContent
            )
        }

        let sandboxURL = try makeSandboxRoot()
        let projectURL = URL(fileURLWithPath: projectPath).resolvingSymlinksInPath()

        let schematizedPaths = Dictionary(
            uniqueKeysWithValues: schematizedFiles.map {
                (URL(fileURLWithPath: $0.originalPath).resolvingSymlinksInPath().path, $0.schematizedContent)
            }
        )

        try populateDirectory(
            source: projectURL,
            destination: sandboxURL,
            schematizedPaths: schematizedPaths,
            mutatedMapping: nil
        )

        try injectSupportFile(
            content: supportFileContent,
            into: sandboxURL,
            schematizedFiles: schematizedFiles,
            projectURL: projectURL
        )

        try disableSwiftLintBuildPhases(in: sandboxURL)

        return Sandbox(rootURL: sandboxURL)
    }

    func createClean(projectPath: String) async throws -> Sandbox {
        if Self.inPlace {
            return Sandbox(rootURL: URL(fileURLWithPath: projectPath).resolvingSymlinksInPath(), isInPlace: true)
        }

        let sandboxURL = try makeSandboxRoot()
        let projectURL = URL(fileURLWithPath: projectPath).resolvingSymlinksInPath()

        try populateDirectory(
            source: projectURL,
            destination: sandboxURL,
            schematizedPaths: [:],
            mutatedMapping: nil
        )

        return Sandbox(rootURL: sandboxURL)
    }

    func create(
        projectPath: String,
        mutatedFilePath: String,
        mutatedContent: String
    ) async throws -> Sandbox {
        if Self.inPlace {
            let projectURL = URL(fileURLWithPath: projectPath).resolvingSymlinksInPath()
            let fileURL = URL(fileURLWithPath: mutatedFilePath).resolvingSymlinksInPath()
            var originals: [Sandbox.OriginalFile] = []
            try writeTracking(Data(mutatedContent.utf8), to: fileURL, originals: &originals)
            try disableSwiftLintBuildPhasesTracking(in: projectURL, originals: &originals)
            return Sandbox(rootURL: projectURL, originals: originals, isInPlace: true)
        }

        let sandboxURL = try makeSandboxRoot()
        let projectURL = URL(fileURLWithPath: projectPath).resolvingSymlinksInPath()
        let mutatedCanonical = URL(fileURLWithPath: mutatedFilePath).resolvingSymlinksInPath().path

        try populateDirectory(
            source: projectURL,
            destination: sandboxURL,
            schematizedPaths: [:],
            mutatedMapping: (path: mutatedCanonical, content: mutatedContent)
        )

        return Sandbox(rootURL: sandboxURL)
    }

    private func createInPlace(
        projectPath: String,
        schematizedFiles: [SchematizedFile],
        supportFileContent: String
    ) throws -> Sandbox {
        let projectURL = URL(fileURLWithPath: projectPath).resolvingSymlinksInPath()
        var originals: [Sandbox.OriginalFile] = []

        for file in schematizedFiles {
            let fileURL = URL(fileURLWithPath: file.originalPath).resolvingSymlinksInPath()
            let content = Data(fixEmptySwitchCaseBodies(file.schematizedContent).utf8)
            try writeTracking(content, to: fileURL, originals: &originals)
        }

        try injectSupportFile(
            content: supportFileContent,
            into: projectURL,
            schematizedFiles: schematizedFiles,
            projectURL: projectURL
        )

        try disableSwiftLintBuildPhasesTracking(in: projectURL, originals: &originals)

        return Sandbox(rootURL: projectURL, originals: originals, isInPlace: true)
    }

    private func writeTracking(_ content: Data, to url: URL, originals: inout [Sandbox.OriginalFile]) throws {
        originals.append(Sandbox.OriginalFile(url: url, content: try? Data(contentsOf: url)))
        try content.write(to: url, options: .atomic)
    }

    private func disableSwiftLintBuildPhasesTracking(
        in projectURL: URL,
        originals: inout [Sandbox.OriginalFile]
    ) throws {
        guard let xcodeprojURL = findXcodeproj(in: projectURL) else { return }
        let pbxprojURL = xcodeprojURL.appendingPathComponent("project.pbxproj")
        let before = try? Data(contentsOf: pbxprojURL)
        try disableSwiftLintBuildPhases(in: projectURL)
        let after = try? Data(contentsOf: pbxprojURL)
        if before != after {
            originals.append(Sandbox.OriginalFile(url: pbxprojURL, content: before))
        }
    }

    private func makeSandboxRoot() throws -> URL {
        let url = SandboxName.directory.appendingPathComponent(SandboxName.make())
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        try initializeIsolatedRepository(at: url)
        return url
    }

    private func initializeIsolatedRepository(at url: URL) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["init", "--quiet", url.path]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()

        let exclude = url.appendingPathComponent(".git/info/exclude")
        try FileManager.default.createDirectory(
            at: exclude.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try "/.xmr-*\n/.derived-data/\n/DerivedData/\n".write(to: exclude, atomically: true, encoding: .utf8)
    }

    private func populateDirectory(
        source: URL,
        destination: URL,
        schematizedPaths: [String: String],
        mutatedMapping: (path: String, content: String)?
    ) throws {
        let items = try FileManager.default.contentsOfDirectory(
            at: source,
            includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey]
        )

        for item in items {
            let name = item.lastPathComponent
            if name == ".git" {
                continue
            }
            let dest = destination.appendingPathComponent(name)
            let values = try item.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
            let isDirectory = values.isDirectory == true
            let isSymlink = values.isSymbolicLink == true

            if isDirectory && !isSymlink {
                if shouldSkip(directoryName: name) {
                    continue
                }

                if name.hasSuffix(".xcodeproj") {
                    try processXcodeproj(source: item, destination: dest)
                    continue
                }

                try FileManager.default.createDirectory(at: dest, withIntermediateDirectories: true)
                try populateDirectory(
                    source: item,
                    destination: dest,
                    schematizedPaths: schematizedPaths,
                    mutatedMapping: mutatedMapping
                )
            } else {
                try writeFile(
                    source: item,
                    destination: dest,
                    schematizedPaths: schematizedPaths,
                    mutatedMapping: mutatedMapping
                )
            }
        }
    }

    private func shouldSkip(directoryName: String) -> Bool {
        directoryName == ".build"
            || directoryName == "DerivedData"
            || directoryName.hasPrefix(".xmr-")
    }

    private func processXcodeproj(source: URL, destination: URL) throws {
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)

        let items = try FileManager.default.contentsOfDirectory(
            at: source,
            includingPropertiesForKeys: [.isDirectoryKey]
        )

        for item in items {
            let name = item.lastPathComponent
            let dest = destination.appendingPathComponent(name)
            let isDir = (try? item.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true

            if isDir && name == "xcuserdata" {
                try FileManager.default.createDirectory(at: dest, withIntermediateDirectories: true)
            } else if isDir && name == "xcshareddata" {
                try FileManager.default.copyItem(at: item, to: dest)
            } else {
                try FileManager.default.copyItem(at: item, to: dest)
            }
        }
    }

    private func writeFile(
        source: URL,
        destination: URL,
        schematizedPaths: [String: String],
        mutatedMapping: (path: String, content: String)?
    ) throws {
        let canonicalPath = source.resolvingSymlinksInPath().path

        if let content = schematizedPaths[canonicalPath] {
            try fixEmptySwitchCaseBodies(content).write(to: destination, atomically: true, encoding: .utf8)
            return
        }

        if let mapping = mutatedMapping, canonicalPath == mapping.path {
            try mapping.content.write(to: destination, atomically: true, encoding: .utf8)
            return
        }

        if source.path.contains(".xcworkspace/xcshareddata/") {
            try FileManager.default.copyItem(at: source, to: destination)
            return
        }

        try FileManager.default.copyItem(at: source, to: destination)
    }

    private func disableSwiftLintBuildPhases(in sandboxURL: URL) throws {
        guard let xcodeprojURL = findXcodeproj(in: sandboxURL) else { return }

        let pbxprojURL = xcodeprojURL.appendingPathComponent("project.pbxproj")

        guard FileManager.default.fileExists(atPath: pbxprojURL.path) else { return }

        let data = try Data(contentsOf: pbxprojURL.resolvingSymlinksInPath())

        var format = PropertyListSerialization.PropertyListFormat.xml

        guard
            var plist = try? PropertyListSerialization.propertyList(
                from: data, options: [], format: &format
            ) as? [String: Any]
        else { return }

        guard var objects = plist["objects"] as? [String: Any] else { return }

        var modified = false

        for (key, value) in objects {
            guard var phase = value as? [String: Any],
                let isa = phase["isa"] as? String,
                isa == "PBXShellScriptBuildPhase",
                let script = phase["shellScript"] as? String,
                script.lowercased().contains("swiftlint")
            else { continue }

            phase["shellScript"] = "exit 0\n"
            objects[key] = phase
            modified = true
        }

        guard modified else { return }

        plist["objects"] = objects

        let xmlData = try PropertyListSerialization.data(
            fromPropertyList: plist, format: .xml, options: 0
        )

        if (try? pbxprojURL.resourceValues(forKeys: [.isSymbolicLinkKey]))?.isSymbolicLink == true {
            try FileManager.default.removeItem(at: pbxprojURL)
        }

        try xmlData.write(to: pbxprojURL, options: .atomic)
    }

    private func findXcodeproj(in directory: URL) -> URL? {
        let items =
            (try? FileManager.default.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: nil
            )) ?? []

        return items.first { $0.pathExtension == "xcodeproj" }
    }

    private func fixEmptySwitchCaseBodies(_ content: String) -> String {
        let lines = content.components(separatedBy: "\n")
        var result: [String] = []

        for idx in 0 ..< lines.count {
            result.append(lines[idx])

            let trimmed = lines[idx].trimmingCharacters(in: .whitespaces)

            guard trimmed.hasPrefix("case \""), trimmed.hasSuffix(":") else { continue }

            var nextIdx = idx + 1
            while nextIdx < lines.count, lines[nextIdx].trimmingCharacters(in: .whitespaces).isEmpty {
                nextIdx += 1
            }

            guard nextIdx < lines.count else { continue }

            let next = lines[nextIdx].trimmingCharacters(in: .whitespaces)
            guard next.hasPrefix("case ") || next.hasPrefix("default") || next == "}" else { continue }

            let indent = String(lines[idx].prefix { $0 == " " || $0 == "\t" })
            result.append(indent + "    break")
        }

        return result.joined(separator: "\n")
    }

    private func injectSupportFile(
        content: String,
        into sandboxURL: URL,
        schematizedFiles: [SchematizedFile],
        projectURL: URL
    ) throws {
        guard !content.isEmpty else { return }

        let computedForm =
            "var __swiftMutationTestingID: String {\n"
            + "    ProcessInfo.processInfo.environment[\"__SWIFT_MUTATION_TESTING_ACTIVE\"] ?? \"\"\n"
            + "}"
        let storedForm =
            "nonisolated(unsafe) var __swiftMutationTestingID: String"
            + " = ProcessInfo.processInfo.environment[\"__SWIFT_MUTATION_TESTING_ACTIVE\"] ?? \"\""
        let content = content.replacingOccurrences(of: computedForm, with: storedForm)

        let sourcesURL = sandboxURL.appendingPathComponent("Sources")

        if FileManager.default.fileExists(atPath: sourcesURL.path) {
            let targetURL = firstSourcesTargetDirectory(in: sourcesURL) ?? sourcesURL
            try content.write(
                to: targetURL.appendingPathComponent("__SMTSupport.swift"),
                atomically: true,
                encoding: .utf8
            )
            return
        }

        guard let firstFile = schematizedFiles.first else { return }

        let originalPath = URL(fileURLWithPath: firstFile.originalPath).resolvingSymlinksInPath().path
        let projectPath = projectURL.path

        guard originalPath.hasPrefix(projectPath) else { return }

        let relative = String(originalPath.dropFirst(projectPath.count + 1))
        let sandboxFileURL = sandboxURL.appendingPathComponent(relative)
        let resolvedURL = sandboxFileURL.resolvingSymlinksInPath()
        let existing = (try? String(contentsOf: resolvedURL, encoding: .utf8)) ?? ""

        try (existing + "\n" + content).write(to: sandboxFileURL, atomically: true, encoding: .utf8)
    }

    private func firstSourcesTargetDirectory(in sourcesURL: URL) -> URL? {
        let items =
            (try? FileManager.default.contentsOfDirectory(
                at: sourcesURL,
                includingPropertiesForKeys: [.isDirectoryKey]
            )) ?? []

        return
            items
            .filter { (try? $0.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
            .first
    }
}
