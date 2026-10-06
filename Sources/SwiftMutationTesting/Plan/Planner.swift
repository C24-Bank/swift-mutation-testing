import Foundation

/// Discovery up to the plan: the files, their hashes, and every mutant with its position and fingerprint.
///
/// The parsed sources come out with the plan so that the direct flow, which materializes the plan right
/// away, does not parse the files twice.
struct Planner: Sendable {
    struct Planned: Sendable {
        let plan: Plan
        let sources: [ParsedSource]
    }

    func plan(
        input: DiscoveryInput, testTarget: String? = nil, container: XcodeContainer? = nil
    ) async throws -> Planned {
        let sourceFiles = try FileDiscoveryStage().run(input: input)
        let parsedSources = await ParsingStage().run(sourceFiles: sourceFiles)
        let operators = DiscoveryPipeline.operators(named: input.operators)
        let mutationPoints = await MutantDiscoveryStage(operators: operators).run(sources: parsedSources)
        let indexed = MutantIndexingStage().run(
            mutationPoints: mutationPoints, sources: parsedSources, projectPath: input.projectPath
        )

        let files =
            sourceFiles
            .map { file in
                Plan.File(
                    path: Self.relative(file.path, to: input.projectPath), sha256: MutantCacheKey.hash(of: file.content)
                )
            }
            .sorted { $0.path < $1.path }
        let mutants = indexed.map { entry in
            Plan.Mutant(
                fingerprint: entry.fingerprint,
                file: Self.relative(entry.mutation.filePath, to: input.projectPath),
                utf8Start: entry.mutation.utf8Offset,
                utf8End: entry.mutation.utf8Offset + entry.mutation.originalText.utf8.count,
                line: entry.mutation.line,
                column: entry.mutation.column,
                operator: entry.mutation.operatorIdentifier,
                replacementKind: entry.mutation.replacement,
                original: entry.mutation.originalText,
                replacement: entry.mutation.mutatedText,
                description: entry.mutation.description,
                schematizable: entry.isSchematizable
            )
        }

        let plan = Plan(
            formatVersion: Plan.formatVersion,
            toolVersion: Version.number,
            project: Plan.Project(type: input.projectType, testTarget: testTarget, container: container),
            scope: Plan.Scope(
                sourcesPath: Self.relative(input.sourcesPath, to: input.projectPath),
                excludePatterns: input.excludePatterns,
                operators: input.operators.isEmpty ? DiscoveryPipeline.allOperatorNames : input.operators
            ),
            files: files,
            mutants: mutants
        )
        return Planned(plan: plan, sources: parsedSources)
    }

    static func relative(_ path: String, to projectPath: String) -> String {
        let root = URL(fileURLWithPath: projectPath).resolvingSymlinksInPath().path
        let resolved = URL(fileURLWithPath: path).resolvingSymlinksInPath().path
        if resolved == root { return "." }
        return ProjectRelativePath.make(for: path, in: projectPath)
    }
}
