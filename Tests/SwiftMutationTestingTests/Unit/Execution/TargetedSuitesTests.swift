import Foundation
import Testing

@testable import SwiftMutationTesting

@Suite("TargetedSuites")
struct TargetedSuitesTests {

    @Test("Given test files, when the suites are read, then only files declaring a type of their own name count")
    func onlyFilesDeclaringTheirOwnTypeCount() throws {
        let dir = try FileHelpers.makeTemporaryDirectory()
        defer { FileHelpers.cleanup(dir) }

        let declared = dir.appendingPathComponent("FooTests.swift")
        let renamed = dir.appendingPathComponent("BarTests.swift")
        let helper = dir.appendingPathComponent("Helpers.swift")
        let notText = dir.appendingPathComponent("BazTests.swift")
        try "@Suite struct FooTests {}".write(to: declared, atomically: true, encoding: .utf8)
        try "final class BarSpecs: XCTestCase {}".write(to: renamed, atomically: true, encoding: .utf8)
        try "struct Helpers {}".write(to: helper, atomically: true, encoding: .utf8)
        try Data([0xFF, 0xFE, 0x00, 0x80]).write(to: notText)

        let suites = TargetedSuites.declared(in: [declared, renamed, helper, notText].map(\.path))

        #expect(suites == ["FooTests"])
    }

    @Test("Given a source file, when its suite is looked up, then it is the file's name plus Tests when declared")
    func aSourceMapsToItsSuiteWhenDeclared() {
        let suites: Set<String> = ["FooTests"]

        #expect(TargetedSuites.suite(for: "/proj/Sources/Foo.swift", among: suites) == "FooTests")
        #expect(TargetedSuites.suite(for: "/proj/Sources/Bar.swift", among: suites) == nil)
    }
}
