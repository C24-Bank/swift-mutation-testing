import Foundation

struct BaselineStore: Sendable {
    func read(from path: String) throws -> Baseline {
        guard FileManager.default.fileExists(atPath: path) else {
            throw GateError.baselineNotFound(path: path)
        }

        let data = try Data(contentsOf: URL(fileURLWithPath: path))

        guard let header = try? JSONDecoder().decode(Header.self, from: data) else {
            throw GateError.unreadableBaseline(path: path)
        }

        guard header.formatVersion == Baseline.formatVersion else {
            throw GateError.unsupportedBaselineVersion(path: path, version: header.formatVersion)
        }

        guard let baseline = try? decoder.decode(Baseline.self, from: data) else {
            throw GateError.unreadableBaseline(path: path)
        }

        return baseline
    }

    func write(_ baseline: Baseline, to path: String) throws {
        let data = try encoder.encode(baseline)
        try (data + Data("\n".utf8)).write(to: URL(fileURLWithPath: path), options: .atomic)
    }

    // MARK: - Private

    private struct Header: Decodable {
        let formatVersion: Int
    }

    private var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    private var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
