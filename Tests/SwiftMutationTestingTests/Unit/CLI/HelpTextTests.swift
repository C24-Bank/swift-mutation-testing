import Testing

@testable import SwiftMutationTesting

@Suite("HelpText")
struct HelpTextTests {
    @Test("Given the help, when the Sonar option is described, then it names the format the reporter writes")
    func sonarOutputIsAGenericIssueImport() throws {
        let line = try #require(HelpText.usage.split(separator: "\n").first { $0.contains("--sonar-output") })

        #expect(line.contains("generic issue import"))
        #expect(!line.lowercased().contains("coverage"))
    }
}
