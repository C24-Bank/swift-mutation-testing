import Foundation

/// Builds a `TestSelection` from the index store an Xcode build left in its derived data.
struct TestSelectionLoader: Sendable {
    let launcher: any ProcessLaunching

    func load(
        derivedDataURL: URL,
        plist: XCTestRunPlist,
        sourceFiles: Set<String>
    ) async throws -> TestSelection {
        let storeURL = derivedDataURL.appendingPathComponent("Index.noindex/DataStore")
        guard FileManager.default.fileExists(atPath: storeURL.path) else {
            throw TestSelectionError.indexStoreNotFound(storeURL.path)
        }

        let reader = TestSelectionIndexReader(storeURL: storeURL, libraryURL: try await libraryURL())
        let facts = try reader.read(sourceFiles: sourceFiles, testTargetsByModule: plist.testTargetsByModule)
        return TestSelection(facts: facts)
    }

    private func libraryURL() async throws -> URL {
        let (exitCode, output) = try await launcher.launchCapturing(
            ProcessRequest(
                executableURL: URL(fileURLWithPath: "/usr/bin/xcrun"),
                arguments: ["--find", "swift"],
                environment: nil,
                additionalEnvironment: [:],
                workingDirectoryURL: URL(fileURLWithPath: "/tmp"),
                timeout: 30
            )
        )

        let swift = output.trimmingCharacters(in: .whitespacesAndNewlines)
        let library = URL(fileURLWithPath: swift)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("lib/libIndexStore.dylib")

        guard exitCode == 0, FileManager.default.fileExists(atPath: library.path) else {
            throw TestSelectionError.libraryNotFound(library.path)
        }
        return library
    }
}

enum TestSelectionError: Error, Equatable, CustomStringConvertible {
    case indexStoreNotFound(String)
    case libraryNotFound(String)

    var description: String {
        switch self {
        case .indexStoreNotFound(let path):
            return "No index store at \(path); test selection needs the build's index."
        case .libraryNotFound(let path):
            return "libIndexStore not found at \(path)."
        }
    }
}
