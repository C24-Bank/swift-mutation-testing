import SwiftIfConfig
import SwiftSyntax
import Testing

@testable import SwiftMutationTesting

@Suite("InactiveRegionExtractor")
struct InactiveRegionExtractorTests {
    private let extractor = InactiveRegionExtractor()

    fileprivate func inactiveText(in code: String) -> [String] {
        let source = makeParsedSource(code)
        return extractor.extractInactiveRanges(from: source.syntax).map { range in
            let utf8 = Array(code.utf8)[range.lowerBound.utf8Offset ..< range.upperBound.utf8Offset]
            return String(decoding: utf8, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    @Test("Given an os(Windows) branch with an else, when extracted, then only the Windows clause is inactive")
    func windowsBranchIsInactive() {
        let code = """
            #if os(Windows)
            let a = 1 + 2
            #else
            let b = 3 + 4
            #endif
            """

        let inactive = inactiveText(in: code)

        #expect(inactive == ["#if os(Windows)\nlet a = 1 + 2"])
    }

    @Test("Given an os(macOS) branch with an else, when extracted, then the else clause is inactive")
    func elseOfActiveBranchIsInactive() {
        let code = """
            #if os(macOS)
            let a = 1 + 2
            #else
            let b = 3 + 4
            #endif
            """

        let inactive = inactiveText(in: code)

        #expect(inactive == ["#else\nlet b = 3 + 4"])
    }

    @Test("Given canImport of an absent module, when extracted, then its clause is inactive")
    func absentModuleIsInactive() {
        let code = """
            #if canImport(Glibc)
            let a = 1 + 2
            #elseif canImport(Darwin)
            let b = 3 + 4
            #endif
            """

        let inactive = inactiveText(in: code)

        #expect(inactive == ["#if canImport(Glibc)\nlet a = 1 + 2"])
    }

    @Test("Given canImport of an unknown module, when extracted, then no clause is inactive")
    func unknownModuleKeepsEveryClause() {
        let code = """
            #if canImport(SomeThirdPartyModule)
            let a = 1 + 2
            #else
            let b = 3 + 4
            #endif
            """

        let inactive = inactiveText(in: code)

        #expect(inactive.isEmpty)
    }

    @Test("Given DEBUG, swift and compiler conditions, when extracted, then the host build answers them")
    func hostConditionsAreAnswered() {
        let code = """
            #if DEBUG
            let a = 1
            #endif
            #if swift(>=5.0)
            let b = 2
            #else
            let c = 3
            #endif
            #if compiler(>=99.0)
            let d = 4
            #endif
            #if arch(wasm32)
            let e = 5
            #endif
            """

        let inactive = inactiveText(in: code)

        #expect(inactive == ["#else\nlet c = 3", "#if compiler(>=99.0)\nlet d = 4", "#if arch(wasm32)\nlet e = 5"])
    }

    @Test("Given no #if at all, when extracted, then there is nothing inactive")
    func plainSourceHasNoInactiveRegion() {
        let inactive = inactiveText(in: "func f() { let x = 1 + 2 }")

        #expect(inactive.isEmpty)
    }
}

extension InactiveRegionExtractorTests {
    @Test("Given an unknown module in an #elseif chain, when extracted, then every clause of that #if is kept")
    func unknownModuleKeepsTheWholeChain() {
        let code = """
            #if canImport(SomeThirdPartyModule)
            let a = 1 + 2
            #elseif os(Windows)
            let b = 3 + 4
            #else
            let c = 5 + 6
            #endif
            #if os(Windows)
            let d = 7 + 8
            #endif
            """

        let inactive = inactiveText(in: code)

        #expect(inactive == ["#if os(Windows)\nlet d = 7 + 8"])
    }

    @Test("Given a decidable #if before an undecidable one, when extracted, then only the decidable one loses a clause")
    func aDecidableIfBeforeAnUndecidableOneIsStillDecided() {
        let code = """
            #if os(Windows)
            let a = 1 + 2
            #else
            let b = 3 + 4
            #endif
            #if canImport(SomeThirdPartyModule)
            let c = 5 + 6
            #else
            let d = 7 + 8
            #endif
            """

        let inactive = inactiveText(in: code)

        #expect(inactive == ["#if os(Windows)\nlet a = 1 + 2"])
    }

    @Test("Given a malformed condition, when extracted, then its #if keeps every clause")
    func malformedConditionKeepsEveryClause() {
        let code = """
            #if someFunction(1)
            let a = 1 + 2
            #else
            let b = 3 + 4
            #endif
            """

        let inactive = inactiveText(in: code)

        #expect(inactive.isEmpty)
    }
}
