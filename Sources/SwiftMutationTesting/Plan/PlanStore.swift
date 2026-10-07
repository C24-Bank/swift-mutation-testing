import Foundation

struct PlanStore: Sendable {
    func read(from path: String) throws -> Plan {
        try VersionedJSON.read(
            Plan.self,
            from: path,
            version: Plan.formatVersion,
            notFound: PlanError.notFound(path: path),
            unreadable: PlanError.unreadable(path: path),
            unsupported: { PlanError.unsupportedVersion(path: path, version: $0) }
        )
    }

    func write(_ plan: Plan, to path: String) throws {
        try Self.encode(plan).write(to: URL(fileURLWithPath: path), options: .atomic)
    }

    /// The bytes of a plan, the same wherever it is encoded. `sha256(of:)` over them is the plan's identity,
    /// the one results carry.
    static func encode(_ plan: Plan) throws -> Data {
        try VersionedJSON.encode(plan)
    }

    static func sha256(of plan: Plan) throws -> String {
        VersionedJSON.sha256(of: try encode(plan))
    }
}
