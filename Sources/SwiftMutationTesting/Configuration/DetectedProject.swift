struct DetectedProject: Sendable {

    static let empty = DetectedProject(
        kind: .xcode(scheme: nil, allSchemes: [], destination: "platform=macOS"),
        testTarget: nil,
        testingFramework: .swiftTesting
    )

    let kind: Kind
    let testTarget: String?
    var testingFramework: TestingFramework = .swiftTesting
    /// The workspace or project `init` found, written to the file so the run needs no flag.
    var xcodeContainer: XcodeContainer?
    /// Why no container was chosen — several at the root, or a workspace reaching outside it — with the
    /// candidates, for the file's comments.
    var containerNote: String?
    var containerCandidates: [XcodeContainer] = []

    enum Kind: Sendable {
        case xcode(scheme: String?, allSchemes: [String], destination: String)
        case spm(testTargets: [String])
    }
}
