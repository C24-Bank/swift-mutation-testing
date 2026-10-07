import Foundation

struct TestExecutionStage: Sendable {
    let deps: ExecutionDeps

    static let loadedTimeoutFactor: Double = 2
    static let retryWorkerShare = 4

    func execute(
        mutants: [MutantDescriptor],
        in context: TestExecutionContext
    ) async throws -> [ExecutionResult] {
        let timeout = context.configuration.build.timeout
        let concurrency = context.configuration.build.concurrency
        var results: [ExecutionResult] = []
        var timedOut: [MutantDescriptor] = []

        try await forEach(mutants, concurrency: concurrency, run: { mutant in
            try await self.attempt(mutant, in: context, timeout: timeout * Self.loadedTimeoutFactor)
        }) { attempt in
            switch attempt {
            case .settled(let result):
                results.append(result)
            case .timedOut(let mutant):
                timedOut.append(mutant)
            }
        }

        try await forEach(timedOut, concurrency: max(1, concurrency / Self.retryWorkerShare), run: { mutant in
            try await self.runAgain(mutant, in: context, timeout: timeout)
        }) { result in
            results.append(result)
        }

        return results
    }

    private func forEach<Element, Outcome: Sendable>(
        _ elements: [Element],
        concurrency: Int,
        run: @escaping @Sendable (Element) async throws -> Outcome,
        collect: (Outcome) -> Void
    ) async throws where Element: Sendable {
        try await withThrowingTaskGroup(of: Outcome.self) { group in
            var activeTasks = 0
            var iterator = elements.makeIterator()

            while activeTasks < concurrency, let element = iterator.next() {
                group.addTask { try await run(element) }
                activeTasks += 1
            }

            for try await outcome in group {
                collect(outcome)

                if let next = iterator.next() {
                    group.addTask { try await run(next) }
                }
            }
        }
    }

    private enum Attempt: Sendable {
        case settled(ExecutionResult)
        case timedOut(MutantDescriptor)
    }

    private func attempt(
        _ mutant: MutantDescriptor,
        in context: TestExecutionContext,
        timeout: Double
    ) async throws -> Attempt {
        let key = MutantCacheKey.make(for: mutant)

        if let cached = await deps.cacheStore.result(for: key) {
            let killerTestFile = await deps.cacheStore.killerTestFile(for: key)
            let result = ExecutionResult(
                descriptor: mutant, status: cached, testDuration: 0, killerTestFile: killerTestFile
            )
            let index = await deps.counter.increment()
            await deps.reporter.report(
                .mutantFinished(descriptor: mutant, status: cached, index: index, total: deps.counter.total))
            return .settled(result)
        }

        let (outcome, launched) = try await measure(mutant, in: context, timeout: timeout)

        if case .timedOut = outcome {
            return .timedOut(mutant)
        }

        return .settled(
            await recordResult(mutant: mutant, key: key, outcome: outcome, launched: launched, in: context)
        )
    }

    private func runAgain(
        _ mutant: MutantDescriptor,
        in context: TestExecutionContext,
        timeout: Double
    ) async throws -> ExecutionResult {
        let key = MutantCacheKey.make(for: mutant)
        let (outcome, launched) = try await measure(mutant, in: context, timeout: timeout)
        return await recordResult(mutant: mutant, key: key, outcome: outcome, launched: launched, in: context)
    }

    private func measure(
        _ mutant: MutantDescriptor,
        in context: TestExecutionContext,
        timeout: Double
    ) async throws -> (TestRunOutcome, TestLaunchResult) {
        guard let plist = context.artifact.plist else {
            return try await measureSPM(mutant, in: context, timeout: timeout)
        }

        let plistData = plist.activating(mutant.id)
        let slot = try await context.pool.acquire()
        let launched: TestLaunchResult
        do {
            launched = try await launch(plistData: plistData, slot: slot, in: context, timeout: timeout)
        } catch {
            await context.pool.release(slot)
            throw error
        }

        await context.pool.release(slot)

        let outcome = try await ResultParser(launcher: deps.launcher).parse(
            exitCode: launched.exitCode,
            output: launched.output,
            xcresultPath: launched.xcresultPath,
            timeout: timeout
        )
        try? FileManager.default.removeItem(atPath: launched.xcresultPath)

        return (outcome, launched)
    }

    private func measureSPM(
        _ mutant: MutantDescriptor,
        in context: TestExecutionContext,
        timeout: Double
    ) async throws -> (TestRunOutcome, TestLaunchResult) {
        let slot = try await context.pool.acquire()

        do {
            let measured = try await measureSPMTargetedFirst(mutant, in: context, timeout: timeout)
            await context.pool.release(slot)
            return measured
        } catch {
            await context.pool.release(slot)
            throw error
        }
    }

    private func measureSPMTargetedFirst(
        _ mutant: MutantDescriptor,
        in context: TestExecutionContext,
        timeout: Double
    ) async throws -> (TestRunOutcome, TestLaunchResult) {
        if let suite = TargetedSuites.suite(for: mutant.filePath, among: context.targetedSuites) {
            let targeted = try await launchSPM(mutant: mutant, in: context, timeout: timeout, filter: suite)
            let outcome = SPMResultParser().parse(exitCode: targeted.exitCode, output: targeted.output)

            if outcome.isKill { return (outcome, targeted) }
        }

        let launched = try await launchSPM(
            mutant: mutant, in: context, timeout: timeout, filter: context.configuration.build.testTarget
        )
        let outcome = SPMResultParser().parse(exitCode: launched.exitCode, output: launched.output)
        return (outcome, launched)
    }

    private func recordResult(
        mutant: MutantDescriptor,
        key: MutantCacheKey,
        outcome: TestRunOutcome,
        launched: TestLaunchResult,
        in context: TestExecutionContext
    ) async -> ExecutionResult {
        let status = outcome.asExecutionStatus
        let duration = launched.duration

        MutantLogWriter(directory: context.configuration.reporting.keepLogsPath)?
            .write(mutant: mutant, status: status, duration: duration, output: launched.output)
        let killerTestFile = resolveKillerTestFile(status: status)
        let result = ExecutionResult(
            descriptor: mutant, status: status, testDuration: duration,
            killerTestFile: killerTestFile
        )
        await deps.cacheStore.store(status: status, for: key, killerTestFile: killerTestFile)
        let index = await deps.counter.increment()
        await deps.reporter.report(
            .mutantFinished(
                descriptor: mutant, status: status,
                index: index, total: deps.counter.total
            )
        )
        return result
    }

    private func resolveKillerTestFile(status: ExecutionStatus) -> String? {
        guard case .killed(let testName) = status else { return nil }
        return deps.killerTestFileResolver.resolve(testName: testName)
    }

    private func launchSPM(
        mutant: MutantDescriptor,
        in context: TestExecutionContext,
        timeout: Double,
        filter: String?
    ) async throws -> TestLaunchResult {
        let start = Date()
        let captured = try await run(
            spmRequests(mutant: mutant, in: context, timeout: timeout, filter: filter),
            deadline: start.addingTimeInterval(timeout)
        )

        return TestLaunchResult(
            exitCode: captured.exitCode,
            output: captured.output,
            xcresultPath: "",
            duration: Date().timeIntervalSince(start)
        )
    }

    private func run(
        _ requests: [ProcessRequest],
        deadline: Date
    ) async throws -> (exitCode: Int32, output: String) {
        var combined = ""

        for request in requests {
            let remaining = deadline.timeIntervalSinceNow

            guard remaining > 0 else {
                return (exitCode: SPMResultParser.timedOutExitCode, output: combined)
            }

            let captured = try await deps.launcher.launchCapturing(request.withTimeout(remaining))

            guard captured.exitCode != TestBundleInvocation.noTestsExitCode else { continue }

            combined += combined.isEmpty ? captured.output : "\n" + captured.output

            guard captured.exitCode == 0 else { return (exitCode: captured.exitCode, output: combined) }
        }

        return (exitCode: 0, output: combined)
    }

    private func spmRequests(
        mutant: MutantDescriptor,
        in context: TestExecutionContext,
        timeout: Double,
        filter: String?
    ) -> [ProcessRequest] {
        let configuration = context.configuration

        if let bundleURL = TestBundleInvocation.bundleURL(in: context.sandbox) {
            return TestBundleInvocation(bundleURL: bundleURL, framework: configuration.build.testingFramework)
                .requests(
                    filter: filter,
                    mutantID: mutant.id,
                    workingDirectory: context.sandbox.rootURL,
                    timeout: timeout,
                    libraries: context.libraries
                )
        }

        var arguments = ["test", "--skip-build"]
        if let filter {
            arguments += ["--filter", filter]
        }

        return [
            ProcessRequest(
                executableURL: URL(fileURLWithPath: "/usr/bin/swift"),
                arguments: arguments,
                environment: nil,
                additionalEnvironment: ["__SWIFT_MUTATION_TESTING_ACTIVE": mutant.id],
                workingDirectoryURL: context.sandbox.rootURL,
                timeout: timeout
            ).stopping(at: .firstTestFailure)
        ]
    }

    private func launch(
        plistData: Data,
        slot: SimulatorSlot,
        in context: TestExecutionContext,
        timeout: Double
    ) async throws -> TestLaunchResult {
        let baseURL =
            context.artifact.xctestrunURL?.deletingLastPathComponent()
            ?? context.sandbox.rootURL
        let xctestrunURL = baseURL.appendingPathComponent("\(UUID().uuidString).xctestrun")
        let xcresultPath = context.sandbox.rootURL
            .appendingPathComponent("\(UUID().uuidString).xcresult").path

        defer { try? FileManager.default.removeItem(at: xctestrunURL) }

        try plistData.write(to: xctestrunURL)

        var arguments = [
            "test-without-building",
            "-xctestrun", xctestrunURL.path,
            "-destination", slot.destination,
            "-resultBundlePath", xcresultPath,
            "-derivedDataPath", context.artifact.derivedDataPath,
            "-collect-test-diagnostics", "never",
        ]

        if let testTarget = context.configuration.build.testTarget {
            arguments += ["-only-testing", testTarget]
        }

        let start = Date()
        let captured = try await deps.launcher.launchCapturing(
            ProcessRequest(
                executableURL: URL(fileURLWithPath: "/usr/bin/xcodebuild"),
                arguments: arguments,
                environment: nil,
                additionalEnvironment: [:],
                workingDirectoryURL: context.sandbox.rootURL,
                timeout: timeout
            )
        )

        return TestLaunchResult(
            exitCode: captured.exitCode,
            output: captured.output,
            xcresultPath: xcresultPath,
            duration: Date().timeIntervalSince(start)
        )
    }
}
