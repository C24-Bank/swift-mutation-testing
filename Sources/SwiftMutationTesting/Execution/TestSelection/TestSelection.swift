import Foundation

/// Maps each source file to the test classes whose files reference a symbol the source file defines.
struct TestSelection: Sendable, Equatable {
    static let xcTestCaseUSR = "c:objc(cs)XCTestCase"

    private let testsByFile: [String: [String]]

    init(testsByFile: [String: [String]]) {
        self.testsByFile = Dictionary(
            uniqueKeysWithValues: testsByFile.map { (Self.normalized($0.key), $0.value) }
        )
    }

    init(facts: TestSelectionFacts) {
        let xcTestClasses = Self.descendants(of: Self.xcTestCaseUSR, in: facts.subclassesByBase)

        let testFiles = facts.testFiles.values.map { file in
            (
                references: file.references,
                identifiers: file.types
                    .filter { $0.isSwiftTestingSuite || xcTestClasses.contains($0.usr) }
                    .map { "\(file.target)/\($0.name)" }
            )
        }
        .filter { !$0.identifiers.isEmpty }

        var testsByFile: [String: [String]] = [:]
        for (sourceFile, definitions) in facts.definitions {
            let identifiers = testFiles
                .filter { !$0.references.isDisjoint(with: definitions) }
                .flatMap(\.identifiers)
            testsByFile[sourceFile] = Array(Set(identifiers)).sorted()
        }
        self.init(testsByFile: testsByFile)
    }

    func tests(for filePath: String) -> [String] {
        testsByFile[Self.normalized(filePath)] ?? []
    }

    func tests(for filePath: String, within testTarget: String?) -> [String] {
        guard let testTarget else { return tests(for: filePath) }
        return tests(for: filePath).filter { $0 == testTarget || $0.hasPrefix(testTarget + "/") }
    }

    var fileCount: Int { testsByFile.count }

    var coveredFileCount: Int { testsByFile.values.filter { !$0.isEmpty }.count }

    static func normalized(_ path: String) -> String {
        URL(fileURLWithPath: path).standardizedFileURL.resolvingSymlinksInPath().path
    }

    private static func descendants(of root: String, in subclassesByBase: [String: Set<String>]) -> Set<String> {
        var found: Set<String> = []
        var pending = [root]
        while let base = pending.popLast() {
            for subclass in subclassesByBase[base, default: []] where found.insert(subclass).inserted {
                pending.append(subclass)
            }
        }
        return found
    }
}

/// What the index says about the files a selection is made from.
struct TestSelectionFacts: Sendable, Equatable {
    /// Symbol USRs defined in each mutated source file.
    var definitions: [String: Set<String>] = [:]
    /// Test files by path.
    var testFiles: [String: TestFileFacts] = [:]
    /// Class USRs that inherit directly from each base class USR, collected from the test modules.
    var subclassesByBase: [String: Set<String>] = [:]
}

struct TestFileFacts: Sendable, Equatable {
    var target: String
    var references: Set<String> = []
    var types: [TestFileType] = []
}

struct TestFileType: Sendable, Equatable {
    let usr: String
    let name: String
    var isSwiftTestingSuite: Bool
}
