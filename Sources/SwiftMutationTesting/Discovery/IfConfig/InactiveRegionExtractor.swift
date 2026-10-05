import SwiftIfConfig
import SwiftSyntax

/// Finds the `#if` clauses the host build leaves out, so their mutants are never counted.
///
/// A clause whose condition cannot be decided (an unknown module under `canImport`, a malformed
/// condition) keeps every clause of its `#if`: dropping a real mutant is the error to avoid.
struct InactiveRegionExtractor: Sendable {
    let compilerVersion: VersionTuple

    init(compilerVersion: VersionTuple = HostBuildConfiguration.hostCompilerVersion) {
        self.compilerVersion = compilerVersion
    }

    func extractInactiveRanges(from syntax: SourceFileSyntax) -> [Range<AbsolutePosition>] {
        let configuration = HostBuildConfiguration(compilerVersion: compilerVersion)
        let regions = syntax.configuredRegions(in: configuration)
        let clauses = regions.map(\.0)
        let errorPositions = regions.diagnostics
            .filter { $0.diagMessage.severity == .error }
            .map(\.position)

        var undecidable = Set<SyntaxIdentifier>()
        for position in errorPositions {
            guard let clause = clauses.first(where: { $0.condition?.range.contains(position) == true }),
                let declaration = Self.declaration(of: clause)
            else {
                return []
            }
            undecidable.insert(declaration.id)
        }

        return regions.compactMap { clause, state in
            guard state != .active else { return nil }
            if let declaration = Self.declaration(of: clause), undecidable.contains(declaration.id) {
                return nil
            }
            return clause.position ..< clause.endPosition
        }
    }

    private static func declaration(of clause: IfConfigClauseSyntax) -> IfConfigDeclSyntax? {
        clause.parent?.parent?.as(IfConfigDeclSyntax.self)
    }
}
