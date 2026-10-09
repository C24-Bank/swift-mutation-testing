import Testing

@testable import SwiftMutationTesting

@Suite("Property initializer closure scopes")
struct PropertyInitializerClosureScopeTests {
    private let lazyClosureCode = """
        final class Model {
            var values: [Int] = []
            lazy var filtered: [Int] = values.filter { [weak self] value in
                guard self != nil else { return false }
                return value > 0 || value < -10
            }
        }
        """

    private func schematizable(_ code: String, op: any MutationOperator) -> [Bool] {
        let source = makeParsedSource(code)
        let visitor = TypeScopeVisitor()
        visitor.walk(source.syntax)
        return op.mutations(in: source).map { visitor.isSchematizable(utf8Offset: $0.utf8Offset) }
    }

    @Test("Given a closure in a lazy var initializer, when visited, then its mutations are schematizable")
    func lazyVarClosureIsSchematizable() {
        #expect(schematizable(lazyClosureCode, op: LogicalOperatorReplacement()) == [true])
    }

    @Test("Given a closure in a static property initializer, when visited, then its mutations are schematizable")
    func staticClosureIsSchematizable() {
        let code = """
            enum Config {
                static let flags: [Bool] = {
                    let a = true
                    return [a || false]
                }()
            }
            """

        #expect(schematizable(code, op: LogicalOperatorReplacement()) == [true])
    }

    @Test("Given a ternary directly in a property initializer, when visited, then it stays incompatible")
    func initializerTernaryStaysIncompatible() {
        let code = "final class Model { let flag = true; lazy var value: Int = flag ? 1 : 2 }"

        #expect(schematizable(code, op: SwapTernary()) == [false])
    }

    @Test("Given a closure inside a function, when visited, then only the function body is a scope")
    func closureInFunctionIsNoScope() {
        let visitor = makeTypeScopeVisitor("func f(values: [Int]) -> [Int] { values.filter { $0 > 0 || $0 < -1 } }")

        #expect(visitor.scopes.count == 1)
    }

    @Test("Given a lazy var closure, when generated, then the switch replaces only its statements")
    func generatorKeepsClosureSignature() {
        let source = makeParsedSource(lazyClosureCode)
        let mutations = mutationsWithIndices(source, op: LogicalOperatorReplacement())

        let result = SchemataGenerator().generate(source: source, mutations: mutations)

        #expect(result.contains("values.filter { [weak self] value in\nswitch __swiftMutationTestingID {"))
        #expect(result.contains("return value > 0 && value < -10"))
        #expect(result.contains("default:\n\n        guard self != nil"))
    }
}
