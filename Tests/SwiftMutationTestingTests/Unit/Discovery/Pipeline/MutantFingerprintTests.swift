import Testing

@testable import SwiftMutationTesting

@Suite("MutantFingerprint")
struct MutantFingerprintTests {
    private let original = """
        struct Validator {
            func isAdult(_ age: Int) -> Bool {
                age >= 18
            }

            func isSenior(_ age: Int) -> Bool {
                age >= 65
            }
        }
        """

    @Test("Given lines inserted above, when fingerprinted again, then every fingerprint is unchanged")
    func stableWhenLinesAreInsertedAbove() {
        let shifted = "import Foundation\n\n// Validation rules\n" + original

        #expect(fingerprints(shifted) == fingerprints(original))
    }

    @Test("Given another function edited, when fingerprinted again, then this function's fingerprints are unchanged")
    func stableWhenAnotherFunctionChanges() {
        let edited = original.replacingOccurrences(of: "age >= 65", with: "age >= 65 && age < 130")

        let before = fingerprints(original, in: "Validator.isAdult(_:)")
        let after = fingerprints(edited, in: "Validator.isAdult(_:)")

        #expect(!before.isEmpty)
        #expect(after == before)
    }

    @Test("Given the function renamed, when fingerprinted again, then its fingerprints change")
    func changesWhenTheFunctionIsRenamed() {
        let renamed = original.replacingOccurrences(of: "func isAdult", with: "func isOfAge")

        #expect(Set(fingerprints(renamed)).isDisjoint(with: fingerprints(original, in: "Validator.isAdult(_:)")))
    }

    @Test("Given the mutated expression edited, when fingerprinted again, then its fingerprints change")
    func changesWhenTheExpressionIsEdited() {
        let edited = original.replacingOccurrences(of: "age >= 18", with: "age > 17")

        #expect(Set(fingerprints(edited)).isDisjoint(with: fingerprints(original, in: "Validator.isAdult(_:)")))
    }

    @Test("Given the same expression twice in one function, when fingerprinted, then the ordinal tells them apart")
    func repeatedExpressionsGetDistinctFingerprints() {
        let code = "func f(_ a: Int, _ b: Int) -> Bool { a < b || a < b }"

        let result = fingerprints(code)

        #expect(result.count == Set(result).count)
    }

    @Test("Given the same project in two directories, when fingerprinted, then the fingerprints are the same")
    func independentOfTheAbsolutePath() {
        let here = fingerprints(original, projectPath: "/Users/a/work/App")
        let there = fingerprints(original, projectPath: "/private/tmp/checkout/App")

        #expect(here == there)
    }

    @Test("Given the same code in two files, when fingerprinted, then the fingerprints differ")
    func dependsOnTheRelativePath() {
        let first = fingerprints(original, file: "Sources/A.swift")
        let second = fingerprints(original, file: "Sources/B.swift")

        #expect(Set(first).isDisjoint(with: second))
    }

    @Test("Given a mutant, when fingerprinted, then the fingerprint is 32 hexadecimal characters")
    func fingerprintIsSixteenBytesOfHex() throws {
        let fingerprint = try #require(fingerprints(original).first)

        #expect(fingerprint.count == 32)
        #expect(fingerprint.allSatisfy { $0.isHexDigit })
    }

    @Test("Given mutants discovered by the pipeline, when turned into descriptors, then each carries its fingerprint")
    func descriptorsCarryTheFingerprint() {
        let source = makeParsedSource(original, path: "/p/Sources/Validator.swift")
        let points = RelationalOperatorReplacement().mutations(in: source)
        let indexed = MutantIndexingStage().run(mutationPoints: points, sources: [source], projectPath: "/p")

        let (_, descriptors) = SchematizationStage().run(indexed: indexed, sources: [source])

        #expect(Set(descriptors.map(\.fingerprint)) == Set(indexed.map(\.fingerprint)))
    }

    private func fingerprints(
        _ code: String,
        file: String = "Sources/Validator.swift",
        projectPath: String = "/project",
        in declaration: String? = nil
    ) -> [String] {
        let source = makeParsedSource(code, path: "\(projectPath)/\(file)")
        let points = RelationalOperatorReplacement().mutations(in: source)
        let indexed = MutantIndexingStage().run(mutationPoints: points, sources: [source], projectPath: projectPath)

        return indexed.filter { point in
            guard let declaration else { return true }
            return DeclarationPath.of(utf8Offset: point.mutation.utf8Offset, in: source.syntax) == declaration
        }.map(\.fingerprint)
    }
}
