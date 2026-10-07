import Testing

@testable import SwiftMutationTesting

@Suite("ExcludePattern")
struct ExcludePatternTests {
    private static let root = "/work/App"

    private func matches(_ pattern: String, _ relative: String) -> Bool {
        ExcludePattern.matches(pattern, path: "\(Self.root)/\(relative)", projectPath: Self.root)
    }

    @Test(
        "Given the documented glob examples, when matched, then they exclude what they say",
        arguments: [
            ("**/Generated/**", "Sources/App/Generated/Model.swift", true),
            ("**/Generated/**", "Generated/Model.swift", true),
            ("**/Generated/**", "Sources/App/Model.swift", false),
            ("**/Generated/**", "Sources/GeneratedCode/Model.swift", false),
            ("Sources/Generated/**", "Sources/Generated/Deep/Model.swift", true),
            ("Sources/Generated/**", "Other/Sources/Generated/Model.swift", false),
            ("**/Tests/**", "Tests/AppTests/AppTests.swift", true),
            ("*.pb.swift", "Sources/Proto/message.pb.swift", true),
            ("*.pb.swift", "Sources/Proto/message.swift", false),
            ("Sources/?pp/*.swift", "Sources/App/Main.swift", true),
            ("Sources/[AB]*/**", "Sources/Billing/Invoice.swift", true),
            ("Sources/[AB]*/**", "Sources/Core/Invoice.swift", false),
        ]
    )
    func globs(pattern: String, relative: String, excluded: Bool) {
        #expect(matches(pattern, relative) == excluded)
    }

    @Test("Given a pattern without glob characters, when matched, then it is a fragment of the path, as before")
    func fragmentsKeepWorking() {
        #expect(matches("/Generated/", "Sources/Generated/Model.swift"))
        #expect(matches("Generated", "Sources/GeneratedCode/Model.swift"))
        #expect(!matches("/Generated/", "Sources/App/Model.swift"))
        #expect(!ExcludePattern.isGlob("/Generated/"))
        #expect(ExcludePattern.isGlob("**/Generated/**"))
    }

    @Test("Given a pattern whose only glob character is ? or [, when checked, then it is a glob")
    func aSingleWildcardCharacterMakesAGlob() {
        #expect(ExcludePattern.isGlob("Sources/?pp.swift"))
        #expect(ExcludePattern.isGlob("Sources/[AB].swift"))
        #expect(ExcludePattern.isGlob("Sources/App*.swift"))
    }

    @Test("Given an absolute glob, when matched, then it matches the absolute path")
    func absoluteGlobs() {
        #expect(matches("/work/App/Sources/Generated/*", "Sources/Generated/Model.swift"))
    }
}
