import Foundation

struct FileSystem: Sendable {
    var fileExists: @Sendable (String) -> Bool = { FileManager.default.fileExists(atPath: $0) }

    var directoryExists: @Sendable (String) -> Bool = { path in
        var isDirectory: ObjCBool = false
        return FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory) && isDirectory.boolValue
    }

    var contentsOfDirectory: @Sendable (String) -> [String] = {
        (try? FileManager.default.contentsOfDirectory(atPath: $0)) ?? []
    }

    var currentDirectory: @Sendable () -> String = { FileManager.default.currentDirectoryPath }

    var createDirectory: @Sendable (URL) throws -> Void = {
        try FileManager.default.createDirectory(at: $0, withIntermediateDirectories: true)
    }

    var removeItem: @Sendable (String) -> Void = { try? FileManager.default.removeItem(atPath: $0) }

    func projectPath(_ path: String) -> String {
        if path == "." || path.isEmpty {
            return currentDirectory()
        }

        return URL(fileURLWithPath: path, isDirectory: true).standardizedFileURL.path
    }
}
