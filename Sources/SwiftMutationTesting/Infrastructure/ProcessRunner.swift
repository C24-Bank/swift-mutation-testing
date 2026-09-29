import Foundation

struct ProcessRunner: Sendable {
    var postTerminationCleanup: (@Sendable (Int32) -> Void)?
    let onTimeout: @Sendable (Int32) -> Void
    var readCapturedOutput: @Sendable (URL) throws -> String = { try String(contentsOf: $0, encoding: .utf8) }

    private struct CaptureTarget {
        let fileHandle: FileHandle
        let tempURL: URL
    }

    private static let pollInterval: Duration = .milliseconds(100)

    final class KilledByUsFlag: @unchecked Sendable {
        private let lock = NSLock()
        private var flag = false

        var value: Bool {
            lock.lock()
            defer { lock.unlock() }
            return flag
        }

        func mark() {
            lock.lock()
            flag = true
            lock.unlock()
        }
    }

    func launch(
        executableURL: URL,
        arguments: [String],
        workingDirectoryURL: URL,
        timeout: Double
    ) async throws -> Int32 {
        let process = Process()
        process.executableURL = executableURL
        process.arguments = arguments
        process.currentDirectoryURL = workingDirectoryURL
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        let killedByUs = KilledByUsFlag()

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                self.startProcess(
                    process, killedByUs: killedByUs, timeout: timeout,
                    continuation: continuation
                )
            }
        } onCancel: {
            killedByUs.mark()
            onTimeout(process.processIdentifier)
        }
    }

    func launchCapturing(
        _ request: ProcessRequest
    ) async throws -> (exitCode: Int32, output: String) {
        let process = Process()
        process.executableURL = request.executableURL
        process.arguments = request.arguments
        process.currentDirectoryURL = request.workingDirectoryURL

        if let environment = request.environment {
            process.environment = environment
        }

        if !request.additionalEnvironment.isEmpty {
            var env = process.environment ?? ProcessInfo.processInfo.environment
            for (key, value) in request.additionalEnvironment {
                env[key] = value
            }
            process.environment = env
        }

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        FileManager.default.createFile(atPath: tempURL.path, contents: nil)
        let fileHandle = try FileHandle(forWritingTo: tempURL)
        process.standardOutput = fileHandle
        process.standardError = fileHandle

        let killedByUs = KilledByUsFlag()
        let stoppedByRule = KilledByUsFlag()

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                self.startCapturingProcess(
                    process, killedByUs: killedByUs, stoppedByRule: stoppedByRule,
                    timeout: request.timeout, stopRule: request.stopRule,
                    capture: CaptureTarget(fileHandle: fileHandle, tempURL: tempURL),
                    continuation: continuation
                )
            }
        } onCancel: {
            killedByUs.mark()
            onTimeout(process.processIdentifier)
        }
    }

    private func startProcess(
        _ process: Process,
        killedByUs: KilledByUsFlag,
        timeout: Double,
        continuation: CheckedContinuation<Int32, any Error>
    ) {
        let timeoutTask = Task {
            try await Task.sleep(for: .seconds(timeout))
            killedByUs.mark()
            onTimeout(process.processIdentifier)
        }

        process.terminationHandler = { proc in
            timeoutTask.cancel()
            postTerminationCleanup?(proc.processIdentifier)
            let exitCode: Int32 = killedByUs.value ? -1 : proc.terminationStatus
            continuation.resume(returning: exitCode)
        }

        do {
            try process.run()
            setpgid(process.processIdentifier, process.processIdentifier)
        } catch {
            timeoutTask.cancel()
            continuation.resume(throwing: error)
        }
    }

    private func startCapturingProcess(
        _ process: Process,
        killedByUs: KilledByUsFlag,
        stoppedByRule: KilledByUsFlag,
        timeout: Double,
        stopRule: OutputStopRule?,
        capture: CaptureTarget,
        continuation: CheckedContinuation<(exitCode: Int32, output: String), any Error>
    ) {
        let timeoutTask = Task {
            let deadline = ContinuousClock.now + .seconds(timeout)

            if let stopRule {
                var watcher = OutputWatcher(url: capture.tempURL, rule: stopRule)

                while ContinuousClock.now < deadline {
                    try await Task.sleep(for: min(Self.pollInterval, deadline - .now))

                    if watcher.sawMarker() {
                        stoppedByRule.mark()
                        onTimeout(process.processIdentifier)
                        return
                    }
                }
            } else {
                try await Task.sleep(until: deadline)
            }

            killedByUs.mark()
            onTimeout(process.processIdentifier)
        }

        process.terminationHandler = { terminated in
            timeoutTask.cancel()
            postTerminationCleanup?(terminated.processIdentifier)
            capture.fileHandle.closeFile()
            let output = (try? readCapturedOutput(capture.tempURL)) ?? ""
            try? FileManager.default.removeItem(at: capture.tempURL)
            let exitCode: Int32
            if stoppedByRule.value, let stopRule {
                exitCode = stopRule.exitCode
            } else {
                exitCode = killedByUs.value ? -1 : terminated.terminationStatus
            }
            continuation.resume(returning: (exitCode: exitCode, output: output))
        }

        do {
            try process.run()
            setpgid(process.processIdentifier, process.processIdentifier)
        } catch {
            timeoutTask.cancel()
            capture.fileHandle.closeFile()
            try? FileManager.default.removeItem(at: capture.tempURL)
            continuation.resume(throwing: error)
        }
    }

}
