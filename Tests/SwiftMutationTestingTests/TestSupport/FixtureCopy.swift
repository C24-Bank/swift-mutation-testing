import Foundation

/// A private copy of a project under `Fixtures/`, so that no two tests ever share a tree.
///
/// Build products and caches are left behind: the executor builds in its own sandbox anyway, and a
/// shared `.swift-mutation-testing-cache` is exactly the state two parallel tests would race on.
struct FixtureCopy {
    let url: URL

    private static let skipped: Set<String> = [
        ".build", ".swift-mutation-testing-cache", ".xmr-cache", ".derived-data", "DerivedData",
    ]

    static func make(_ name: String) throws -> FixtureCopy {
        let source = fixturesRoot.appending(path: name)
        let root = FileManager.default.temporaryDirectory
            .appending(path: "swift-mutation-testing-fixtures")
            .appending(path: UUID().uuidString)
        let destination = root.appending(path: name)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try copy(source, to: destination)
        return FixtureCopy(url: destination)
    }

    func remove() {
        try? FileManager.default.removeItem(at: url.deletingLastPathComponent())
    }

    private static var fixturesRoot: URL {
        URL(filePath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appending(path: "Fixtures")
    }

    private static func copy(_ source: URL, to destination: URL) throws {
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        let items = try FileManager.default.contentsOfDirectory(
            at: source, includingPropertiesForKeys: [.isDirectoryKey]
        )
        for item in items where !skipped.contains(item.lastPathComponent) {
            let target = destination.appending(path: item.lastPathComponent)
            if try item.resourceValues(forKeys: [.isDirectoryKey]).isDirectory == true {
                try copy(item, to: target)
            } else {
                try FileManager.default.copyItem(at: item, to: target)
            }
        }
    }
}
