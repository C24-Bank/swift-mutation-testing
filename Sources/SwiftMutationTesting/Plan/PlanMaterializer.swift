import Foundation

/// Plan → `RunnerInput`: the schematized content regenerated from the plan's mutants, the incompatible
/// ones rewritten, every descriptor rebuilt with the id and fingerprint the plan gives it.
///
/// This is the one path from mutants to an executable input. The direct flow hands over the sources it has
/// just parsed; a `run --plan` reads them from disk and refuses to go on if any differs from the plan.
struct PlanMaterializer: Sendable {
    struct ExecutionOptions: Sendable {
        let timeout: Double
        let concurrency: Int
        let noCache: Bool
    }

    func materialize(
        plan: Plan, projectPath: String, execution: ExecutionOptions, mutants selection: [Plan.Mutant]? = nil
    ) async throws -> RunnerInput {
        let sources = try load(plan: plan, projectPath: projectPath)
        let parsed = await ParsingStage().run(sourceFiles: sources)
        return try materialize(
            plan: plan, projectPath: projectPath, sources: parsed, execution: execution, mutants: selection
        )
    }

    func materialize(
        plan: Plan,
        projectPath: String,
        sources: [ParsedSource],
        execution: ExecutionOptions,
        mutants selection: [Plan.Mutant]? = nil
    ) throws -> RunnerInput {
        let selected = Set((selection ?? plan.mutants).map(\.fingerprint))
        // The sources carry the paths discovery saw, symlinks resolved or not; the plan's relative paths
        // are matched to them, never rebuilt, so every later lookup by path agrees.
        let sourceByRelativePath = Dictionary(
            sources.map { (Planner.relative($0.file.path, to: projectPath), $0) },
            uniquingKeysWith: { first, _ in first }
        )
        let indexed: [IndexedMutationPoint] = try plan.mutants.enumerated().compactMap { index, mutant in
            guard selected.contains(mutant.fingerprint) else { return nil }
            guard let source = sourceByRelativePath[mutant.file] else {
                throw PlanError.missingFile(file: mutant.file)
            }
            return IndexedMutationPoint(
                index: index,
                mutation: MutationPoint(
                    operatorIdentifier: mutant.operator,
                    filePath: source.file.path,
                    line: mutant.line,
                    column: mutant.column,
                    utf8Offset: mutant.utf8Start,
                    originalText: mutant.original,
                    mutatedText: mutant.replacement,
                    replacement: mutant.replacementKind,
                    description: mutant.description
                ),
                isSchematizable: mutant.schematizable,
                fingerprint: mutant.fingerprint
            )
        }

        let (schematizedFiles, schematizable) = SchematizationStage().run(indexed: indexed, sources: sources)
        let incompatible = IncompatibleRewritingStage().run(indexed: indexed, sources: sources)
        let descriptors = (schematizable + incompatible).sorted { Self.index(of: $0.id) < Self.index(of: $1.id) }

        guard let projectType = plan.project.projectType else {
            throw PlanError.unknownProjectType(plan.project.type)
        }

        return RunnerInput(
            projectPath: projectPath,
            projectType: projectType,
            timeout: execution.timeout,
            concurrency: execution.concurrency,
            noCache: execution.noCache,
            schematizedFiles: schematizedFiles,
            mutants: descriptors,
            importStyle: ImportStyle.of(sources)
        )
    }

    /// The plan's files as they are on disk now, or the reason the plan can no longer be trusted.
    func load(plan: Plan, projectPath: String) throws -> [SourceFile] {
        var sources: [SourceFile] = []
        for file in plan.files {
            let path = Self.absolute(file.path, in: projectPath)
            guard let content = try? String(contentsOfFile: path, encoding: .utf8) else {
                throw PlanError.missingFile(file: file.path)
            }
            guard MutantCacheKey.hash(of: content) == file.sha256 else {
                throw PlanError.stale(file: file.path)
            }
            sources.append(SourceFile(path: path, content: content))
        }

        let contentByFile = Dictionary(uniqueKeysWithValues: zip(plan.files.map(\.path), sources.map(\.content)))
        for mutant in plan.mutants {
            guard let content = contentByFile[mutant.file] else { throw PlanError.missingFile(file: mutant.file) }
            let bytes = Array(content.utf8)
            guard
                mutant.utf8Start >= 0, mutant.utf8End <= bytes.count, mutant.utf8Start <= mutant.utf8End,
                Array(mutant.original.utf8) == Array(bytes[mutant.utf8Start ..< mutant.utf8End])
            else {
                throw PlanError.corrupt(fingerprint: mutant.fingerprint, file: mutant.file)
            }
        }

        return sources
    }

    /// The path discovery would have seen: the file enumerator yields the root's real path, so this does too.
    static func absolute(_ relativePath: String, in projectPath: String) -> String {
        let root = URL(fileURLWithPath: CanonicalPath.make(for: projectPath))
        return relativePath == "." ? root.path : root.appendingPathComponent(relativePath).path
    }

    private static func index(of id: String) -> Int {
        Int(id.replacingOccurrences(of: "swift-mutation-testing_", with: "")) ?? 0
    }
}
