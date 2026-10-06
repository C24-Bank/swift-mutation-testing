/// What a run is going to do, written down before any build: the project, the scope, the files with a
/// hash of their content, and every mutant with a position and a fingerprint.
///
/// A plan carries no absolute path and no execution option — timeout, concurrency, cache are the run's
/// business — so two plans of the same code are the same bytes wherever they were made, and a plan made
/// on one machine runs on another. The schematized content is not in it either: the run regenerates it
/// from the mutants, which keeps the plan small enough to read.
struct Plan: Sendable, Codable, Equatable {
    static let formatVersion = 1

    let formatVersion: Int
    let toolVersion: String
    let project: Project
    let scope: Scope
    let files: [File]
    let mutants: [Mutant]

    struct Project: Sendable, Codable, Equatable {
        let type: String
        let scheme: String?
        let destination: String?
        let testTarget: String?
        /// The `.xcworkspace` or `.xcodeproj` the plan was made for, relative to the root; absent for a
        /// package and for an Xcode root without one, so such plans keep their bytes.
        var workspace: String?
        var xcodeProject: String?

        init(type: ProjectType, testTarget: String?, container: XcodeContainer? = nil) {
            switch type {
            case .spm:
                self.type = "spm"
                scheme = nil
                destination = nil
            case .xcode(let scheme, let destination):
                self.type = "xcode"
                self.scheme = scheme
                self.destination = destination
            }
            self.testTarget = testTarget
            switch container {
            case .workspace(let path): workspace = path
            case .project(let path): xcodeProject = path
            case nil: break
            }
        }

        var xcodeContainer: XcodeContainer? {
            workspace.map(XcodeContainer.workspace) ?? xcodeProject.map(XcodeContainer.project)
        }

        var projectType: ProjectType? {
            switch type {
            case "spm": .spm
            case "xcode":
                if let scheme, let destination { .xcode(scheme: scheme, destination: destination) } else { nil }
            default: nil
            }
        }
    }

    struct Scope: Sendable, Codable, Equatable {
        let sourcesPath: String
        let excludePatterns: [String]
        let operators: [String]
    }

    struct File: Sendable, Codable, Equatable {
        let path: String
        let sha256: String
    }

    struct Mutant: Sendable, Codable, Equatable {
        let fingerprint: String
        let file: String
        let utf8Start: Int
        let utf8End: Int
        let line: Int
        let column: Int
        let operatorIdentifier: String
        let replacementKind: ReplacementKind
        let original: String
        let replacement: String
        let description: String
        let schematizable: Bool
    }

    /// The report id of the mutant at `index` of `mutants`, the same id the direct flow gives it.
    static func mutantID(at index: Int) -> String {
        "swift-mutation-testing_\(index)"
    }
}

extension Plan.Mutant {
    /// The plan's bytes keep the key `operator`, so a plan's hash does not change with the Swift name.
    enum CodingKeys: String, CodingKey {
        case fingerprint, file, utf8Start, utf8End, line, column
        case operatorIdentifier = "operator"
        case replacementKind, original, replacement, description, schematizable
    }
}
