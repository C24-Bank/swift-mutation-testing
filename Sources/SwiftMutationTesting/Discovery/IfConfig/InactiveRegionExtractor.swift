import SwiftIfConfig
import SwiftSyntax

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

        // `nil` when an error lies outside every condition: then no clause is dropped.
        let undecidable = Self.undecidableDeclarations(at: errorPositions, among: clauses)

        return regions.compactMap { clause, state in
            guard state != .active, let undecidable else { return nil }
            if let declaration = Self.declaration(of: clause), undecidable.contains(declaration.id) {
                return nil
            }
            return clause.position ..< clause.endPosition
        }
    }

    static func undecidableDeclarations(
        at errorPositions: [AbsolutePosition],
        among clauses: [IfConfigClauseSyntax]
    ) -> Set<SyntaxIdentifier>? {
        var undecidable = Set<SyntaxIdentifier>()
        for position in errorPositions {
            guard let clause = clauses.first(where: { $0.condition?.range.contains(position) == true }),
                let declaration = declaration(of: clause)
            else {
                return nil
            }
            undecidable.insert(declaration.id)
        }
        return undecidable
    }

    private static func declaration(of clause: IfConfigClauseSyntax) -> IfConfigDeclSyntax? {
        clause.parent?.parent?.as(IfConfigDeclSyntax.self)
    }
}
