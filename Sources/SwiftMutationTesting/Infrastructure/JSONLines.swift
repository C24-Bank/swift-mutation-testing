import Foundation

enum JSONLines {
    static func append(_ value: some Encodable, to path: String) {
        guard var line = try? JSONEncoder().encode(value) else { return }
        line.append(UInt8(ascii: "\n"))

        let url = URL(fileURLWithPath: path)
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        if let handle = try? FileHandle(forWritingTo: url) {
            defer { try? handle.close() }
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: line)
        } else {
            try? line.write(to: url)
        }
    }

    static func read<Value: Decodable>(_ type: Value.Type, from path: String) -> [Value] {
        guard let data = FileManager.default.contents(atPath: path) else { return [] }

        return data.split(separator: UInt8(ascii: "\n")).compactMap { line in
            try? JSONDecoder().decode(Value.self, from: line)
        }
    }
}
