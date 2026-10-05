import CryptoKit
import Foundation

struct PlanStore: Sendable {
    func read(from path: String) throws -> Plan {
        guard FileManager.default.fileExists(atPath: path) else {
            throw PlanError.notFound(path: path)
        }

        let data = try Data(contentsOf: URL(fileURLWithPath: path))

        guard let header = try? JSONDecoder().decode(Header.self, from: data) else {
            throw PlanError.unreadable(path: path)
        }

        guard header.formatVersion == Plan.formatVersion else {
            throw PlanError.unsupportedVersion(path: path, version: header.formatVersion)
        }

        guard let plan = try? JSONDecoder().decode(Plan.self, from: data) else {
            throw PlanError.unreadable(path: path)
        }

        return plan
    }

    func write(_ plan: Plan, to path: String) throws {
        try Self.encode(plan).write(to: URL(fileURLWithPath: path), options: .atomic)
    }

    /// The bytes of a plan, the same wherever it is encoded: sorted keys, no escaped slashes, one trailing
    /// newline. `sha256(of:)` over them is the plan's identity, the one results carry.
    static func encode(_ plan: Plan) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(plan) + Data("\n".utf8)
    }

    static func sha256(of plan: Plan) throws -> String {
        let digest = SHA256.hash(data: try encode(plan))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    // MARK: - Private

    private struct Header: Decodable {
        let formatVersion: Int
    }
}
