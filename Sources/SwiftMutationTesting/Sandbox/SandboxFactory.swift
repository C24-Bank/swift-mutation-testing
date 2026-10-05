import Foundation

struct SandboxFactory: Sendable {
    func create(
        projectPath: String,
        schematizedFiles: [SchematizedFile]
    ) async throws -> Sandbox {
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

        try disableSwiftLintBuildPhases(in: sandboxURL)

        return Sandbox(rootURL: sandboxURL)
    }

    func createClean(projectPath: String) async throws -> Sandbox {
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

    private func makeSandboxRoot() throws -> URL {
        let url = SandboxName.directory.appendingPathComponent(SandboxName.make())
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
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
                try FileManager.default.createSymbolicLink(at: dest, withDestinationURL: item)
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
            try content.write(to: destination, atomically: true, encoding: .utf8)
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

        try FileManager.default.createSymbolicLink(at: destination, withDestinationURL: source)
    }

    /// Every project of the sandbox, the root's and the workspace's alike: a SwiftLint phase left in any
    /// of them lints the schematized code and fails the build.
    private func disableSwiftLintBuildPhases(in sandboxURL: URL) throws {
        for xcodeprojURL in Self.xcodeprojs(in: sandboxURL) {
            try disableSwiftLintBuildPhases(inProject: xcodeprojURL)
        }
    }

    private func disableSwiftLintBuildPhases(inProject xcodeprojURL: URL) throws {
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

    /// The `.xcodeproj` directories under `directory`, at any depth, in path order; build products,
    /// derived data and `Pods/` are not looked into.
    static func xcodeprojs(in directory: URL) -> [URL] {
        let skipped: Set<String> = [".build", "DerivedData", "Pods", ".xmr-derived-data", ".derived-data"]
        var found: [URL] = []
        var pending = [directory]
        while let current = pending.popLast() {
            let items =
                (try? FileManager.default.contentsOfDirectory(
                    at: current, includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey]
                )) ?? []
            for item in items {
                let values = try? item.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
                guard values?.isDirectory == true, values?.isSymbolicLink != true else { continue }
                if item.pathExtension == "xcodeproj" {
                    found.append(item)
                } else if !skipped.contains(item.lastPathComponent), item.pathExtension != "xcworkspace" {
                    pending.append(item)
                }
            }
        }
        return found.sorted { $0.path < $1.path }
    }
}
