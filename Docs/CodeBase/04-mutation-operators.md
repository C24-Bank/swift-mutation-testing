# Mutation Operators

← [Discovery Pipeline](03-discovery-pipeline.md) | Next: [Schematization →](05-schematization.md)

---

## Discovery/Operators/MutationOperator.swift

```swift
protocol MutationOperator: Sendable {
    func mutations(in source: ParsedSource) -> [MutationPoint]
}
```

All seven mutation operators conform to this protocol. Each implementation creates its visitor, walks the AST, and returns the collected mutation points.

---

## Discovery/Operators/MutationSyntaxVisitor.swift

```swift
class MutationSyntaxVisitor: SyntaxVisitor {
    let filePath: String
    let locationConverter: SourceLocationConverter
    var mutations: [MutationPoint]

    init(source: ParsedSource)
    override func visit(_ node: IfConfigClauseSyntax) -> SyntaxVisitorContinueKind
}
```

Every operator's visitor inherits one rule: the condition of an `#if`, `#elseif` or `#else` clause is never visited. It is a compile-time expression — `#if DEBUG && !os(Windows)`, `#elseif compiler(<6.1)` — whose `&&`, `||`, `<` and literals are not code that runs, and a mutation there changes what compiles instead of what executes. The clause's code is walked as usual, whichever branch the build will take: a mutant inside a branch the build leaves out compiles to nothing and can only survive, which the campaign in `Docs/OPERATORS.md` records as not measurable.

Base class for all operator visitors. Subclasses override `visit(_:)` methods to detect applicable nodes and append `MutationPoint` values to `mutations`.

| Field | Description |
|---|---|
| `filePath` | Passed into every `MutationPoint` |
| `locationConverter` | Converts `AbsolutePosition` to line/column |
| `mutations` | Accumulated mutation points; read after `walk(_:)` |

---

## Discovery/Operators/ReplacementKind.swift

```swift
enum ReplacementKind: String, Sendable, Codable {
    case binaryOperator
    case prefixOperator
    case booleanLiteral
    case swapTernary
    case removeStatement
    case wrapWithNegation
}
```

Classifies the structural shape of the replacement, independent of the specific tokens involved.

| Case | Used by |
|---|---|
| `binaryOperator` | `RelationalOperatorReplacement`, `LogicalOperatorReplacement`, `ArithmeticOperatorReplacement` |
| `prefixOperator` | (reserved) |
| `booleanLiteral` | `BooleanLiteralReplacement` |
| `swapTernary` | `SwapTernary` |
| `removeStatement` | `RemoveSideEffects` |
| `wrapWithNegation` | `NegateConditional` |

---

## RelationalOperatorReplacement

```swift
struct RelationalOperatorReplacement: MutationOperator, Sendable {
    func mutations(in source: ParsedSource) -> [MutationPoint]
}
```

Replaces comparison operators with their complements. Each token may produce multiple `MutationPoint` values (one per replacement).

**Replacement table:**

| Original | Replacements |
|---|---|
| `>` | `>=`, `<` |
| `>=` | `>`, `<=` |
| `<` | `<=`, `>` |
| `<=` | `<`, `>=` |
| `==` | `!=` |
| `!=` | `==` |

Visitor: `RelationalOperatorVisitor` — visits `BinaryOperatorExprSyntax`.

---

## BooleanLiteralReplacement

```swift
struct BooleanLiteralReplacement: MutationOperator, Sendable {
    func mutations(in source: ParsedSource) -> [MutationPoint]
}
```

Flips `true` ↔ `false`.

Visitor: `BooleanLiteralVisitor` — visits `BooleanLiteralExprSyntax`.

---

## LogicalOperatorReplacement

```swift
struct LogicalOperatorReplacement: MutationOperator, Sendable {
    func mutations(in source: ParsedSource) -> [MutationPoint]
}
```

Swaps `&&` ↔ `||`.

Visitor: `LogicalOperatorVisitor` — visits `BinaryOperatorExprSyntax` where the operator token is `&&` or `||`.

---

## ArithmeticOperatorReplacement

```swift
struct ArithmeticOperatorReplacement: MutationOperator, Sendable {
    func mutations(in source: ParsedSource) -> [MutationPoint]
}
```

Swaps arithmetic operators: `+` ↔ `-`, `*` ↔ `/`, `%` → `*`.

Skips `+` and `-` when either operand is a string literal, which would otherwise produce `"a" - "b"`. The check walks the token's enclosing expression list to find the operands; a `+` that is not part of a binary expression at all — an operator *declaration*, for instance — has no operands to inspect and is mutated like any other.

The `*` of an availability check, `#available(macOS 10.15, *)` or `@available(*, deprecated)`, is tokenized as a binary operator too; its parent is an `AvailabilityArgumentSyntax`, and the visitor leaves it alone.

Visitor: `ArithmeticOperatorVisitor` — visits `BinaryOperatorExprSyntax`.

---

## NegateConditional

```swift
struct NegateConditional: MutationOperator, Sendable {
    func mutations(in source: ParsedSource) -> [MutationPoint]
}
```

Wraps a condition expression in `!()`.

Visitor: `NegateConditionalVisitor` — visits `ConditionElementSyntax`.

---

## SwapTernary

```swift
struct SwapTernary: MutationOperator, Sendable {
    func mutations(in source: ParsedSource) -> [MutationPoint]
}
```

Swaps the true and false branches of a ternary expression.

The mutation is anchored on the **whole** ternary — condition, `?`, both branches — not on the condition alone. Anchoring on the condition turns `flag ? a : b` into `flag ? b : a ? a : b`, which either fails to compile or means something else entirely. In a chain (`a ? b : c ? d : e`) the visitor walks back to the nearest preceding ternary to find where its own condition starts, so each link swaps its own branches.

A ternary whose branches are identical is skipped at discovery: swapping them produces the same program, and an equivalent mutant can only ever be reported as survived.

The condition, the branches and the original text are joined from the expression list's elements; the first element's leading trivia is dropped, so a comment above the statement is not part of the mutation and the text starts where its offset says.

Visitor: `SwapTernaryVisitor` — visits `UnresolvedTernaryExprSyntax`.

---

## RemoveSideEffects

```swift
struct RemoveSideEffects: MutationOperator, Sendable {
    func mutations(in source: ParsedSource) -> [MutationPoint]
}
```

Removes standalone function call statements. Three things are never removed, each because removing them produces a mutant that cannot compile rather than one the tests could catch:

**Deny-list:** `print`, `debugPrint`, `assert`, `assertionFailure`, `precondition`, `preconditionFailure`, `fatalError` — plus `super.init` and `self.init`, since an initializer that does not delegate does not compile.

**Sole statement of a body.** A call that is the only statement of a closure, an accessor block, a `switch` case, or the body of a function, initializer, deinitializer or accessor is left alone: removing it empties the body, and an empty `case` is a compile error for the whole file, not just for that mutant. `if`, `for`, `while`, `do` and `defer` bodies may be emptied and are still mutated.

**Inside a `while` or `repeat`.** Handled by the infinite-loop filter below, not by the operator itself.

Visitor: `RemoveSideEffectsVisitor` — visits `CodeBlockItemSyntax` whose expression is a function call. The reported line, column and offset come from the node's position after leading trivia, so a call preceded by a comment is reported at the call.

---

## Suppression

### Discovery/Suppression/SuppressionAnnotationExtractor.swift

```swift
struct SuppressionAnnotationExtractor: Sendable {
    func extractSuppressedRanges(from syntax: SourceFileSyntax) -> [Range<AbsolutePosition>]
}
```

Delegates to `SuppressionVisitor` and returns the collected suppressed byte ranges.

---

### Discovery/Suppression/SuppressionFilter.swift

```swift
struct SuppressionFilter: Sendable {
    func filter(_ points: [MutationPoint], suppressedRanges: [Range<AbsolutePosition>]) -> [MutationPoint]
}
```

Removes any `MutationPoint` whose `utf8Offset` (as `AbsolutePosition`) falls within a suppressed range.

---

### Discovery/Suppression/SuppressionVisitor.swift

```swift
final class SuppressionVisitor: SyntaxVisitor {
    var suppressedRanges: [Range<AbsolutePosition>]
}
```

Walks the AST looking for the `@SwiftMutationTestingDisabled` attribute. When found on a supported declaration, the declaration's full source range is recorded in `suppressedRanges`.

**Supported declaration kinds:**

`FunctionDeclSyntax`, `InitializerDeclSyntax`, `ClassDeclSyntax`, `StructDeclSyntax`, `EnumDeclSyntax`, `ExtensionDeclSyntax`, `VariableDeclSyntax`

---

## Infinite-loop prevention

Two operators can turn a terminating loop into one that never ends: `ArithmeticOperatorReplacement`, which can flip the step that moves an index towards its bound, and `RemoveSideEffects`, which can delete the statement that advances it. A mutant like that does not fail the tests — it hangs them, and the run pays the full `--timeout` for a verdict of `Timeout` that says nothing about the test suite.

Mutation points of those two operators are therefore dropped at discovery when they fall inside the body of a `while` or a `repeat`. `for` loops are left alone: they iterate a sequence, and neither operator can make that sequence infinite.

### Discovery/InfiniteLoopPrevention/InfiniteLoopBodyVisitor.swift

```swift
final class InfiniteLoopBodyVisitor: SyntaxVisitor {
    private(set) var loopBodyRanges: [Range<AbsolutePosition>]
}
```

Collects the body range of every `WhileStmtSyntax` and `RepeatStmtSyntax`, nested ones included.

### Discovery/InfiniteLoopPrevention/InfiniteLoopBodyExtractor.swift

```swift
struct InfiniteLoopBodyExtractor: Sendable {
    func extractLoopBodyRanges(from syntax: SourceFileSyntax) -> [Range<AbsolutePosition>]
}
```

Walks the file once with `InfiniteLoopBodyVisitor` and returns what it found.

### Discovery/InfiniteLoopPrevention/InfiniteLoopFilter.swift

```swift
struct InfiniteLoopFilter: Sendable {
    func filter(
        _ mutationPoints: [MutationPoint],
        loopBodyRanges: [Range<AbsolutePosition>]
    ) -> [MutationPoint]
}
```

Removes the points of the two risky operators whose `utf8Offset` falls inside a collected range. Every other operator passes through untouched, and a file with no `while` or `repeat` returns its points unchanged without any range checks.

`MutantDiscoveryStage` applies this after `SuppressionFilter`, so a suppressed region is never even considered.

---

← [Discovery Pipeline](03-discovery-pipeline.md) | Next: [Schematization →](05-schematization.md)
