struct FallbackExecutor: Sendable {
    let deps: ExecutionDeps
    let configuration: RunnerConfiguration

    private var recorder: ResultRecorder {
        ResultRecorder(deps: deps, keepLogsPath: configuration.reporting.keepLogsPath)
    }

    func execute(input: RunnerInput, pool: SimulatorPool) async throws -> [ExecutionResult] {
        var results: [ExecutionResult] = []

        for file in input.schematizedFiles {
            results += try await processFile(file: file, input: input, pool: pool)
        }

        return results
    }

    private func processFile(
        file: SchematizedFile,
        input: RunnerInput,
        pool: SimulatorPool
    ) async throws -> [ExecutionResult] {
        let fileMutants = input.mutants.filter { $0.filePath == file.originalPath && $0.isSchematizable }

        guard !fileMutants.isEmpty else { return [] }

        if let cached = await cachedResults(for: fileMutants) {
            return cached
        }

        let sandbox = try await SandboxFactory().create(
            projectPath: input.projectPath,
            schematizedFiles: [file]
        )
        defer { sandbox.release(keepingFor: configuration.build.reproduction) }

        try ApplicationVerifier().verify(
            schematizedFiles: [file], mutants: fileMutants, sandbox: sandbox, projectPath: input.projectPath
        )

        await deps.reporter.report(.fallbackBuildStarted(filePath: file.originalPath))

        let artifact: BuildArtifact
        switch configuration.build.projectType {
        case .xcode(let scheme, let destination):
            do {
                artifact = try await BuildStage(launcher: deps.launcher).build(
                    sandbox: sandbox,
                    container: configuration.build.xcodeContainer,
                    scheme: scheme,
                    destination: destination,
                    timeout: configuration.build.buildTimeout
                )
                await deps.reporter.report(.fallbackBuildFinished(filePath: file.originalPath, success: true))
            } catch {
                await deps.reporter.report(.fallbackBuildFinished(filePath: file.originalPath, success: false))
                return await markBuildFailure(error, mutants: fileMutants)
            }

        case .spm:
            do {
                artifact = try await BuildStage(launcher: deps.launcher).buildSPM(
                    sandbox: sandbox,
                    timeout: configuration.build.buildTimeout
                )
                await deps.reporter.report(.fallbackBuildFinished(filePath: file.originalPath, success: true))
            } catch {
                await deps.reporter.report(.fallbackBuildFinished(filePath: file.originalPath, success: false))
                return await markBuildFailure(error, mutants: fileMutants)
            }
        }

        let selection = TestTargetSelection.make(
            target: configuration.build.testTarget, bundleURLs: TestBundleInvocation.bundleURLs(in: sandbox)
        )
        let context = TestExecutionContext(
            artifact: artifact, sandbox: sandbox, pool: pool,
            configuration: configuration,
            bundles: selection.bundleURLs.map { TestBundle(url: $0, libraries: TestBundle.allLibraries) },
            testFilter: selection.filter
        )

        return try await TestExecutionStage(deps: deps).execute(mutants: fileMutants, in: context)
    }

    private func cachedResults(for mutants: [MutantDescriptor]) async -> [ExecutionResult]? {
        var results: [ExecutionResult] = []
        for mutant in mutants {
            guard let result = await deps.cacheStore.cachedResult(for: mutant) else { return nil }
            results.append(result)
        }

        for result in results {
            await recorder.finish(result)
        }

        return results
    }

    private func isTimeout(_ error: any Error) -> Bool {
        guard case BuildError.timedOut = error else { return false }
        return true
    }

    private func markBuildFailure(
        _ error: any Error,
        mutants: [MutantDescriptor]
    ) async -> [ExecutionResult] {
        let status: ExecutionStatus = isTimeout(error) ? .timeout : .unviable

        var results: [ExecutionResult] = []
        for mutant in mutants {
            results.append(await recorder.record(mutant, status: status, output: error.localizedDescription))
        }
        return results
    }
}
