import Foundation
import Testing

@testable import SwiftMutationTesting

@Suite("TestSelection")
struct TestSelectionTests {
    private let source = "/project/Sources/Validator.swift"
    private let validate = "s:6Module9ValidatorV8validateyyF"

    private func testFile(
        _ target: String,
        references: Set<String>,
        types: [TestFileType]
    ) -> TestFileFacts {
        TestFileFacts(target: target, references: references, types: types)
    }

    private func xcTestClass(_ name: String) -> TestFileType {
        TestFileType(usr: "c:objc(cs)\(name)", name: name, isSwiftTestingSuite: false)
    }

    @Test("Given an XCTest class referencing a symbol of the file, when selected, then it is a Target/Class identifier")
    func xcTestClassReferencingTheFileIsSelected() {
        let facts = TestSelectionFacts(
            definitions: [source: [validate]],
            testFiles: ["/project/Tests/ValidatorTests.swift": testFile(
                "C24 MockedTests", references: [validate], types: [xcTestClass("ValidatorTests")]
            )],
            subclassesByBase: [TestSelection.xcTestCaseUSR: ["c:objc(cs)ValidatorTests"]]
        )

        #expect(TestSelection(facts: facts).tests(for: source) == ["C24 MockedTests/ValidatorTests"])
    }

    @Test("Given a class inheriting XCTestCase through a base class, when selected, then it counts as a test class")
    func xcTestClassThroughBaseClassIsSelected() {
        let facts = TestSelectionFacts(
            definitions: [source: [validate]],
            testFiles: ["/project/Tests/ValidatorTests.swift": testFile(
                "AppTests", references: [validate], types: [xcTestClass("ValidatorTests")]
            )],
            subclassesByBase: [
                TestSelection.xcTestCaseUSR: ["c:objc(cs)BaseTestCase"],
                "c:objc(cs)BaseTestCase": ["c:objc(cs)ValidatorTests"],
            ]
        )

        #expect(TestSelection(facts: facts).tests(for: source) == ["AppTests/ValidatorTests"])
    }

    @Test("Given a Swift Testing suite and a helper type in the same file, when selected, then only the suite is")
    func onlySwiftTestingSuitesAndNotHelpersAreSelected() {
        let facts = TestSelectionFacts(
            definitions: [source: [validate]],
            testFiles: ["/project/Tests/ValidatorTests.swift": testFile(
                "ModuleTests",
                references: [validate],
                types: [
                    TestFileType(usr: "s:11ModuleTests09ValidatorB0V", name: "ValidatorTests", isSwiftTestingSuite: true),
                    TestFileType(usr: "s:11ModuleTests12MockedClientC", name: "MockedClient", isSwiftTestingSuite: false),
                ]
            )]
        )

        #expect(TestSelection(facts: facts).tests(for: source) == ["ModuleTests/ValidatorTests"])
    }

    @Test("Given test files that reference none of the file's symbols, when selected, then the file has no tests")
    func unrelatedTestsAreNotSelected() {
        let facts = TestSelectionFacts(
            definitions: [source: [validate]],
            testFiles: ["/project/Tests/OtherTests.swift": testFile(
                "ModuleTests",
                references: ["s:6Module5OtherV"],
                types: [TestFileType(usr: "s:11ModuleTests05OtherB0V", name: "OtherTests", isSwiftTestingSuite: true)]
            )]
        )

        let selection = TestSelection(facts: facts)

        #expect(selection.tests(for: source).isEmpty)
        #expect(selection.coveredFileCount == 0)
        #expect(selection.fileCount == 1)
    }

    @Test("Given a test target, when selected within it, then only that target's classes remain")
    func selectionWithinATestTarget() {
        let selection = TestSelection(testsByFile: [source: ["AppTests/ATests", "ModuleTests/BTests"]])

        #expect(selection.tests(for: source, within: "ModuleTests") == ["ModuleTests/BTests"])
        #expect(selection.tests(for: source, within: nil) == ["AppTests/ATests", "ModuleTests/BTests"])
    }

    @Test("Given an xctestrun, when its test targets are read, then they are keyed by module name")
    func xctestrunMapsModulesToTargets() throws {
        let plist: [String: Any] = [
            "TestConfigurations": [
                [
                    "TestTargets": [
                        ["BlueprintName": "C24 MockedTests", "ProductModuleName": "C24_MockedTests"],
                        ["BlueprintName": "CashflowTests", "ProductModuleName": "CashflowTests"],
                    ]
                ]
            ],
            "__xctestrun_metadata__": ["FormatVersion": 2],
        ]
        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)

        let targets = try #require(XCTestRunPlist(data)).testTargetsByModule

        #expect(targets == ["C24_MockedTests": "C24 MockedTests", "CashflowTests": "CashflowTests"])
    }
}
