import Foundation

struct ApplicationVerifier: Sendable {
    func verify(
        schematizedFiles: [SchematizedFile],
        mutants: [MutantDescriptor],
        sandbox: Sandbox,
        projectPath: String
    ) throws {
        let projectRoot = URL(fileURLWithPath: projectPath).resolvingSymlinksInPath().path
        var written: [String: String] = [:]

        for file in schematizedFiles {
            let original = URL(fileURLWithPath: file.originalPath).resolvingSymlinksInPath().path

            guard
                original.hasPrefix(projectRoot + "/"),
                let content = try? String(
                    contentsOfFile: sandbox.rootURL.path + original.dropFirst(projectRoot.count), encoding: .utf8
                ),
                content != (try? String(contentsOfFile: original, encoding: .utf8))
            else { throw IntegrityError.schemaNotApplied(path: file.originalPath) }

            guard content.contains(SupportDeclarations.perFile) else {
                throw IntegrityError.supportMissing(path: file.originalPath)
            }

            written[original] = content
        }

        let missing = mutants.filter { !isApplied($0, written: written) }.map(\.id)

        guard missing.isEmpty else { throw IntegrityError.mutantsNotApplied(ids: missing) }
    }

    // MARK: - Private

    private func isApplied(_ mutant: MutantDescriptor, written: [String: String]) -> Bool {
        guard mutant.isSchematizable else {
            guard let mutated = mutant.mutatedSourceContent else { return false }
            return mutated != (try? String(contentsOfFile: mutant.filePath, encoding: .utf8))
        }

        let path = URL(fileURLWithPath: mutant.filePath).resolvingSymlinksInPath().path
        return written[path]?.contains("case \"\(mutant.id)\":") == true
    }
}
