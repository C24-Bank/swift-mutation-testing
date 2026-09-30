struct ExecutionResult: Sendable, Codable {

    init(
        descriptor: MutantDescriptor,
        status: ExecutionStatus,
        testDuration: Double,
        killerTestFile: String? = nil,
        activated: Bool? = nil
    ) {
        self.descriptor = descriptor
        self.status = status
        self.testDuration = testDuration
        self.killerTestFile = killerTestFile
        self.activated = activated
    }

    let descriptor: MutantDescriptor
    let status: ExecutionStatus
    let testDuration: Double
    let killerTestFile: String?
    let activated: Bool?
}
