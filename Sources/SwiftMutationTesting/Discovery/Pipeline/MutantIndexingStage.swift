import SwiftSyntax

struct MutantIndexingStage: Sendable {
    func run(mutationPoints: [MutationPoint], sources: [ParsedSource], projectPath: String) -> [IndexedMutationPoint] {
        let sorted = mutationPoints.sorted {
            if $0.filePath != $1.filePath { return $0.filePath < $1.filePath }
            return $0.utf8Offset < $1.utf8Offset
        }

        let visitors = buildVisitors(for: sources)
        let syntaxByPath = Dictionary(uniqueKeysWithValues: sources.map { ($0.file.path, $0.syntax) })
        var ordinals: [[String]: Int] = [:]

        return sorted.enumerated().map { index, mutation in
            let schematizable = visitors[mutation.filePath]?.isSchematizable(utf8Offset: mutation.utf8Offset) ?? false
            let relativePath = ProjectRelativePath.make(for: mutation.filePath, in: projectPath)
            let declarationPath =
                syntaxByPath[mutation.filePath].map {
                    DeclarationPath.of(utf8Offset: mutation.utf8Offset, in: $0)
                } ?? DeclarationPath.topLevel
            let identity = [
                relativePath, declarationPath, mutation.operatorIdentifier, mutation.originalText, mutation.mutatedText,
            ]
            let ordinal = ordinals[identity, default: 0]
            ordinals[identity] = ordinal + 1

            return IndexedMutationPoint(
                index: index,
                mutation: mutation,
                isSchematizable: schematizable,
                fingerprint: MutantFingerprint.make(
                    relativePath: relativePath,
                    declarationPath: declarationPath,
                    mutation: mutation,
                    ordinal: ordinal
                )
            )
        }
    }

    private func buildVisitors(for sources: [ParsedSource]) -> [String: TypeScopeVisitor] {
        var visitors: [String: TypeScopeVisitor] = [:]
        for source in sources {
            let visitor = TypeScopeVisitor()
            visitor.walk(source.syntax)
            visitors[source.file.path] = visitor
        }
        return visitors
    }
}
