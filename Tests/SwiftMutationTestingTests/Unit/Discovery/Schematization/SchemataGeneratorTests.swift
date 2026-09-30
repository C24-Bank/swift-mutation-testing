import SwiftParser
import Testing

@testable import SwiftMutationTesting

@Suite("SchemataGenerator")
struct SchemataGeneratorTests {
    private let generator = SchemataGenerator()

    @Test("Given one mutation, when generated, then produces switch with one case and default")
    func oneMutationProducesSwitchWithOneCaseAndDefault() {
        let source = makeParsedSource("func f() { let x = true }")
        let mutations = mutationsWithIndices(source)
        let result = generator.generate(source: source, mutations: mutations)
        #expect(result.contains("switch __swiftMutationTestingID"))
        #expect(result.contains("case \"swift-mutation-testing_0\""))
        #expect(result.contains("default:"))
    }

    @Test("Given mutation, when generated, then mutated text appears in case body")
    func mutatedTextAppearsInCaseBody() {
        let source = makeParsedSource("func f() { let x = true }")
        let mutations = mutationsWithIndices(source)
        let result = generator.generate(source: source, mutations: mutations)
        #expect(result.contains("false"))
    }

    @Test("Given mutation, when generated, then original text appears in default body")
    func originalTextAppearsInDefaultBody() {
        let source = makeParsedSource("func f() { let x = true }")
        let mutations = mutationsWithIndices(source)
        let result = generator.generate(source: source, mutations: mutations)
        #expect(result.contains("true"))
    }

    @Test("Given two mutations in same function, when generated, then produces switch with two cases")
    func twoMutationsInSameFunctionProduceTwoCases() {
        let source = makeParsedSource("func f() { let a = true; let b = false }")
        let mutations = mutationsWithIndices(source)
        let result = generator.generate(source: source, mutations: mutations)
        #expect(result.contains("case \"swift-mutation-testing_0\""))
        #expect(result.contains("case \"swift-mutation-testing_1\""))
    }

    @Test("Given mutations in two functions, when generated, then each function gets its own switch")
    func mutationsInTwoFunctionsEachGetOwnSwitch() {
        let source = makeParsedSource("func f() { let x = true } func g() { let y = false }")
        let mutations = mutationsWithIndices(source)
        let result = generator.generate(source: source, mutations: mutations)
        let switchCount = result.components(separatedBy: "switch __swiftMutationTestingID").count - 1
        #expect(switchCount == 2)
    }

    @Test("Given generated content, when checked, then it ends with its own private __swiftMutationTestingID")
    func schematizedContentDeclaresItsOwnIDVariable() {
        let source = makeParsedSource("func f() { let x = true }")
        let mutations = mutationsWithIndices(source)
        let result = generator.generate(source: source, mutations: mutations)
        #expect(result.hasSuffix("\n\n" + SupportDeclarations.perFile + "\n"))
        #expect(result.components(separatedBy: "private var __swiftMutationTestingID").count == 2)
    }

    @Test("Given a body of statements, when generated, then every case records its activation before them")
    func everyCaseRecordsItsActivationFirst() {
        let source = makeParsedSource("func f() { let x = true }\nfunc g() { let y = false }")
        let mutations = mutationsWithIndices(source)
        let result = generator.generate(source: source, mutations: mutations)
        let lines = result.components(separatedBy: "\n")
        let caseLines = lines.indices.filter { lines[$0].hasPrefix("case \"swift-mutation-testing_") }

        #expect(caseLines.count == 2)
        #expect(caseLines.allSatisfy { lines[$0 + 1] == "let _ = " + SupportDeclarations.activationCall })
        #expect(!result.contains("default:\nlet _ ="))
    }

    @Test("Given a body that is one expression, when generated, then the case stays one expression")
    func anExpressionBodyStaysAnExpression() {
        let source = makeParsedSource("func add(_ a: Int, _ b: Int) -> Int { a + b }")
        let mutations = ArithmeticOperatorReplacement().mutations(in: source).enumerated().map {
            (index: $0.offset, point: $0.element)
        }
        let result = generator.generate(source: source, mutations: mutations)

        let activation = SupportDeclarations.activationCall
        #expect(result.contains("case \"swift-mutation-testing_0\":\n(\(activation), a - b ).1\n"))
        #expect(result.contains("default:\na + b \n"))
        #expect(!result.contains("let _ ="))
    }

    @Test("Given a mutation that empties a one-expression body, when generated, then the case only records activation")
    func anEmptiedExpressionBodyLeavesOnlyTheActivation() {
        let source = makeParsedSource("func f() { store() }")
        let real = ArithmeticOperatorReplacement().mutations(in: makeParsedSource("func f() { a + b }"))[0]
        let removal = MutationPoint(
            operatorIdentifier: "RemoveSideEffects", filePath: real.filePath, line: 1, column: 12,
            utf8Offset: 11, originalText: "store()", mutatedText: "", replacement: real.replacement,
            description: "remove store()"
        )
        let result = generator.generate(source: source, mutations: [(index: 0, point: removal)])

        let activation = SupportDeclarations.activationCall
        #expect(result.contains("case \"swift-mutation-testing_0\":\nlet _ = \(activation)\n \n"))
        #expect(!result.contains(").1"))
    }

    @Test("Given a value-returning body that is one if expression, when generated, then every branch returns it")
    func aConditionalReturningBodyReturnsInEveryBranch() {
        let source = makeParsedSource("func f(_ c: Bool) -> Int { if c { 1 } else { 2 } }")
        let mutations = NegateConditional().mutations(in: source).enumerated().map {
            (index: $0.offset, point: $0.element)
        }
        let result = generator.generate(source: source, mutations: mutations)

        #expect(result.contains("let _ = \(SupportDeclarations.activationCall)\nreturn if !(c) { 1 } else { 2 } \n"))
        #expect(result.contains("default:\nreturn if c { 1 } else { 2 } \n"))
    }

    @Test("Given a body that is one if statement returning nothing, when generated, then no branch returns")
    func aConditionalVoidBodyDoesNotReturn() {
        let source = makeParsedSource("func f(_ c: Bool) { if c { print(1) } }")
        let mutations = NegateConditional().mutations(in: source).enumerated().map {
            (index: $0.offset, point: $0.element)
        }
        let result = generator.generate(source: source, mutations: mutations)

        let schema = result.components(separatedBy: SupportDeclarations.perFile)[0]
        #expect(schema.contains("let _ = \(SupportDeclarations.activationCall)\nif !(c) { print(1) } \n"))
        #expect(!schema.contains("return"))
    }

    @Test("Given no mutations in function, when generated, then returns original content unchanged")
    func emptyMutationsReturnsOriginalContent() {
        let source = makeParsedSource("func f() { let x = 1 }")
        let result = generator.generate(source: source, mutations: [])
        #expect(result == source.file.content)
    }

    @Test("Given mutation uses correct mutant ID format, when generated, then ID matches swift-mutation-testing prefix")
    func mutantIDUsesCorrectFormat() {
        let source = makeParsedSource("func f() { let x = true }")
        let mutations = mutationsWithIndices(source, startIndex: 5)
        let result = generator.generate(source: source, mutations: mutations)
        #expect(result.contains("swift-mutation-testing_5"))
    }

    @Test("Given mutation at file scope, when generated, then returns original content unchanged")
    func mutationAtFileScopeIsSkipped() {
        let source = makeParsedSource("let x = true")
        let mutations = mutationsWithIndices(source)
        #expect(!mutations.isEmpty)
        let result = generator.generate(source: source, mutations: mutations)
        #expect(result == source.file.content)
    }

    @Test("Given generated content, when parsed by SwiftSyntax, then has no syntax errors")
    func generatedContentIsParseableBySwiftSyntax() {
        let source = makeParsedSource("func f() { let x = true; let y = false }")
        let mutations = mutationsWithIndices(source)
        let result = generator.generate(source: source, mutations: mutations)
        #expect(!Parser.parse(source: result).hasError)
    }
}
