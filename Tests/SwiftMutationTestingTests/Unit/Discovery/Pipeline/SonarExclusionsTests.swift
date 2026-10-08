import Foundation
import Testing

@testable import SwiftMutationTesting

@Suite("SonarExclusions")
struct SonarExclusionsTests {
    private func matches(_ glob: String, _ path: String) -> Bool {
        let regex = try? NSRegularExpression(pattern: SonarExclusions.regex(forGlob: glob))
        return regex?.firstMatch(in: path, range: NSRange(path.startIndex..., in: path)) != nil
    }

    @Test("Given Sonar globs, when matched against paths, then ** spans directories and * stays within one segment")
    func globMatching() {
        #expect(matches("**/*Page.swift", "C24/Profile/ProfilePage.swift"))
        #expect(matches("**/*Page.swift", "ProfilePage.swift"))
        #expect(matches("**/*Page.swift", "C24/Profile/ProfilePageViewModel.swift") == false)
        #expect(matches("**/*Mock*", "C24/Card/MockedCardManager.swift"))
        #expect(matches("**/DI/**", "Modules/Cashflow/Sources/DI/CashflowDependencies.swift"))
        #expect(matches("**/DI/**", "Modules/Cashflow/Sources/Manager/DIHelper.swift") == false)
        #expect(matches("Modules/UIComponent/**/*", "Modules/UIComponent/Sources/UIComponent/Tile.swift"))
        #expect(matches("Modules/UIComponent/**/*", "Modules/Cashflow/Sources/Tile.swift") == false)
        #expect(matches("**/*Generated*/**", "Modules/C24Resources/Sources/C24Resources/Generated/Strings.swift"))
        #expect(matches("**/StartPageV2.swift", "C24/StartPageV2/StartPageV2.swift"))
        #expect(matches("**/StartPageV2.swift", "C24/StartPageV2/StartPageV2Header.swift") == false)
    }

    @Test("Given properties with comments and line continuations, when parsed, then multi-line values are joined")
    func parsesContinuations() {
        let properties = """
            # comment
            sonar.projectBaseDir= ../
            sonar.exclusions= Pods/**/*, **/*Mock*
            sonar.coverage.exclusions= \\
                **/*Adapter*, \\
                **/*Page.swift
            """

        let parsed = SonarExclusions.parse(properties: properties)

        #expect(parsed["sonar.projectBaseDir"] == "../")
        #expect(parsed["sonar.exclusions"] == "Pods/**/*, **/*Mock*")
        #expect(parsed["sonar.coverage.exclusions"]?.contains("**/*Adapter*") == true)
        #expect(parsed["sonar.coverage.exclusions"]?.contains("**/*Page.swift") == true)
    }

    @Test("Given a properties file with a base directory, when loaded, then paths are matched relative to it")
    func loadsRelativeToBaseDirectory() throws {
        let root = try FileHelpers.makeTemporaryDirectory()
        defer { FileHelpers.cleanup(root) }
        let sonar = root.appendingPathComponent("Sonarcube")
        try FileManager.default.createDirectory(at: sonar, withIntermediateDirectories: true)
        try "sonar.projectBaseDir= ../\nsonar.coverage.exclusions= **/*Page.swift, **/DI/**\n"
            .write(to: sonar.appendingPathComponent("sonar-project.properties"), atomically: true, encoding: .utf8)

        let exclusions = try SonarExclusions.load(propertiesPath: sonar.appendingPathComponent("sonar-project.properties").path)

        #expect(exclusions.excludes(path: root.appendingPathComponent("C24/Login/LoginPage.swift").path))
        #expect(exclusions.excludes(path: root.appendingPathComponent("C24/Login/DI/LoginDependencies.swift").path))
        #expect(exclusions.excludes(path: root.appendingPathComponent("C24/Login/LoginViewModel.swift").path) == false)
    }
}
