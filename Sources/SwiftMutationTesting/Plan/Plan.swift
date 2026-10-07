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
}

extension Plan.Mutant {
    enum CodingKeys: String, CodingKey {
        case fingerprint, file, utf8Start, utf8End, line, column
        case operatorIdentifier = "operator"
        case replacementKind, original, replacement, description, schematizable
    }
}
