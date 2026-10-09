import Testing

@testable import SwiftMutationTesting

@Suite("Coverage block suppression")
struct CoverageBlockSuppressionTests {
    private func lines(_ code: String, excludeCoverageBlocks: Bool) async -> [Int] {
        let stage = MutantDiscoveryStage(operators: [NegateConditional()], excludeCoverageBlocks: excludeCoverageBlocks)
        return await stage.run(sources: [makeParsedSource(code)]).map(\.line)
    }

    private let ifConfigCode = """
        func f(a: Bool) {
            if a { print(1) }
            #if DEBUG
            if a { print(2) }
            #endif
        }
        """

    private let markerCode = """
        func f(a: Bool) {
            if a { print(1) }
            // START-COVERAGE-EXCLUSION
            if a { print(2) }
            // END-COVERAGE-EXCLUSION
            if a { print(3) }
        }
        """

    @Test("Given an #if block, when coverage blocks are excluded, then mutations inside it are dropped")
    func ifConfigBlockIsSuppressed() async {
        #expect(await lines(ifConfigCode, excludeCoverageBlocks: true) == [2])
    }

    @Test("Given an #if block, when coverage blocks are not excluded, then mutations inside it are kept")
    func ifConfigBlockIsKeptByDefault() async {
        #expect(await lines(ifConfigCode, excludeCoverageBlocks: false) == [2, 4])
    }

    @Test("Given coverage-exclusion markers, when coverage blocks are excluded, then mutations between them are dropped")
    func markerRangeIsSuppressed() async {
        #expect(await lines(markerCode, excludeCoverageBlocks: true) == [2, 6])
    }

    @Test("Given coverage-exclusion markers, when coverage blocks are not excluded, then nothing is dropped")
    func markersAreIgnoredByDefault() async {
        #expect(await lines(markerCode, excludeCoverageBlocks: false) == [2, 4, 6])
    }

    @Test("Given a start marker without an end marker, when coverage blocks are excluded, then the rest of the file is dropped")
    func unterminatedMarkerRunsToEndOfFile() async {
        let code = """
            func f(a: Bool) {
                if a { print(1) }
                // START-COVERAGE-EXCLUSION
                if a { print(2) }
                if a { print(3) }
            }
            """

        #expect(await lines(code, excludeCoverageBlocks: true) == [2])
    }
}
