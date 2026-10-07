extension SimulatorPool {
    /// The pool a run's destination needs: clones of its simulator, or plain slots for a Mac or a package.
    static func make(
        for configuration: RunnerConfiguration, launcher: any ProcessLaunching
    ) async throws -> SimulatorPool {
        let destination: String
        if case .xcode(_, let dest) = configuration.build.projectType {
            destination = dest
        } else {
            destination = "platform=macOS"
        }

        guard SimulatorManager.requiresSimulatorPool(for: destination) else {
            return SimulatorPool(
                baseUDID: nil, size: configuration.build.concurrency,
                destination: destination, launcher: launcher
            )
        }

        let baseUDID = try await SimulatorManager(launcher: launcher)
            .resolveBaseUDID(for: destination)

        return SimulatorPool(
            baseUDID: baseUDID, size: configuration.build.concurrency,
            destination: destination, launcher: launcher
        )
    }
}
