# Discovery Pipeline

← [Overview](01-overview.md) | Next: [Execution Pipeline →](03-execution.md)

---

## Design

The discovery pipeline is a **linear chain of pure stages**. Each stage receives an immutable input, produces an immutable output, and has no side effects. `DiscoveryPipeline` is the entry point and orchestrates the six stages sequentially.

```mermaid
flowchart TD
    IN[DiscoveryInput] --> FD[FileDiscoveryStage]
    FD --> PA[ParsingStage]
    PA --> MD[MutantDiscoveryStage]
    MD --> MI[MutantIndexingStage]
    MI --> SC[SchematizationStage]
    MI --> IR[IncompatibleRewritingStage]
    SC --> OUT[RunnerInput]
    IR --> OUT
```

## Stages

### FileDiscoveryStage

Collects Swift source files under the configured sources path.

| | |
|---|---|
| Input | `DiscoveryInput` — project path, sources path, exclude patterns |
| Output | `[SourceFile]` — path + raw text content |

Traverses the directory tree recursively. Excludes files matching any `--exclude` pattern — a glob against the path relative to the project root, or a fragment of the path — and files located under paths that contain `Tests`, `Specs`, `.build`, or similar test-only indicators. Each discovered file is read into a `SourceFile` value.

### ParsingStage

Parses each source file into a SwiftSyntax AST. Runs concurrently across files via `async` iteration.

| | |
|---|---|
| Input | `[SourceFile]` |
| Output | `[ParsedSource]` — `SourceFile` + `SourceFileSyntax` tree |

Files that fail to parse are silently dropped. The resulting `[ParsedSource]` array contains only successfully parsed files.

### MutantDiscoveryStage

Applies mutation operators to each parsed source and collects mutation points. Runs concurrently across files.

| | |
|---|---|
| Input | `[ParsedSource]`, resolved `[any MutationOperator]` |
| Output | `[MutationPoint]` — file path, position, original text, mutated text, operator |

Each operator walks the AST with its own visitor and emits a `MutationPoint` for every applicable node. The points of each file then pass through the stage's exclusions in turn — suppression, infinite-loop prevention and inactive `#if` branches, below — each a `MutationExclusion` that names the ranges it covers and the points it applies to. Points are collected from all operators and all files, then returned as a flat list.

### MutantIndexingStage

Assigns unique sequential IDs to each mutation point and classifies them as schematizable or incompatible.

| | |
|---|---|
| Input | `[MutationPoint]`, `[ParsedSource]` |
| Output | `[IndexedMutationPoint]` — mutation point + unique ID + schematizable flag + fingerprint |

Each mutation point receives an ID in the format `swift-mutation-testing_<index>`, where `<index>` is a zero-based global counter. `MutantID` is the one place that builds, reads and orders that format. `TypeScopeVisitor` determines whether a mutation falls inside a function body (schematizable) or outside (incompatible). The indexed points are consumed by the next two stages.

The ID is only unique within one run: a mutant added earlier in any file renumbers every later one. Each point therefore also gets a **fingerprint** — a hash of its project-relative file, the declaration that contains it (`Parser.parse(_:)`), its operator and its change — which stays the same when other code moves or changes. The quality gate matches baselines by fingerprint.

### SchematizationStage

Embeds all schematizable mutations into the source files via `SchemataGenerator`, producing `SchematizedFile` values and `MutantDescriptor` values for the execution pipeline.

| | |
|---|---|
| Input | `[IndexedMutationPoint]`, `[ParsedSource]` |
| Output | `[SchematizedFile]`, `[MutantDescriptor]` — schematized files and schematizable mutant descriptors |

For each file, the stage processes only the schematizable indexed points. Mutations are embedded into the source via `SchemataGenerator`, which rewrites function bodies to contain `switch __swiftMutationTestingID_<hash>` blocks, the hash naming the file. See [Schematization](05-schematization.md) for a detailed breakdown.

### IncompatibleRewritingStage

Produces full-file rewrites for mutants that cannot be schematized (mutations outside function bodies, such as stored property initializers or global-scope expressions).

| | |
|---|---|
| Input | `[IndexedMutationPoint]`, `[ParsedSource]` |
| Output | `[MutantDescriptor]` — incompatible mutant descriptors with pre-computed `mutatedSourceContent` |

Each incompatible mutation point is applied to the source via `MutationRewriter`, producing a complete replacement source file stored in `MutantDescriptor.mutatedSourceContent`. These mutants are executed later by `IncompatibleMutantExecutor`, each requiring a separate build + test cycle.

## Mutation Operators

All operators implement the `MutationOperator` protocol and are registered in `OperatorRegistry`. Each is a `VisitorOperator` over a dedicated `Visitor` that extends `MutationSyntaxVisitor`; the visitor declares the operator's name, its description and whether it is loop-risky, and the rest of the tool — configuration, tiers, SARIF rules, the infinite-loop filter — reads those from the operator rather than from lists of its own.

| Operator | What it mutates | Example |
|---|---|---|
| `RelationalOperatorReplacement` | Comparison operators | `>` → `>=`, `<` → `<=`, `==` → `!=` |
| `BooleanLiteralReplacement` | Boolean literals | `true` → `false`, `false` → `true` |
| `LogicalOperatorReplacement` | Logical connectives | `&&` → `\|\|`, `\|\|` → `&&` |
| `ArithmeticOperatorReplacement` | Arithmetic operators | `+` → `-`, `-` → `+`, `*` → `/`, `/` → `*` |
| `NegateConditional` | Conditional expressions | `condition` → `!condition` |
| `SwapTernary` | Ternary branches | `a ? b : c` → `a ? c : b` |
| `RemoveSideEffects` | Standalone function call statements | `doSomething()` → *(removed)* |

Operators are activated by name via `--operator` or deactivated via `--disable-mutator`. If neither flag is provided, the operators of the `--operator-tier` are active — the `default` tier unless configured otherwise. The tiers and the measurements behind them are in [`Docs/OPERATORS.md`](../OPERATORS.md).

## Suppression

Mutations are suppressed with comments, which need nothing declared in the user's project: `// swift-mutation-testing:disable` above a declaration suppresses the declaration, and `// swift-mutation-testing:disable-next-line` suppresses the line after it. `SuppressionAnnotationExtractor` walks the file and records the range of every suppressed declaration and line, and `SuppressionFilter` removes any `MutationPoint` falling inside one before the points reach `MutantIndexingStage`. The `@SwiftMutationTestingDisabled` attribute the documentation used to recommend is still honoured, but Swift only accepts it where the project declares it, so it is no longer the documented way.

## Infinite-loop prevention

`ArithmeticOperatorReplacement` and `RemoveSideEffects` can turn a terminating loop into one that never ends — by flipping the step that moves an index towards its bound, or by deleting the statement that advances it. A mutant like that does not fail the tests, it hangs them, and the run pays the full `--timeout` for a `Timeout` verdict that says nothing about the suite.

`InfiniteLoopBodyExtractor` collects the body range of every `while` and `repeat`, and `InfiniteLoopFilter` drops the points of those two operators — the ones that declare themselves loop-risky — that fall inside one. `for` loops are left alone: they iterate a sequence, and neither operator can make that sequence infinite. The filter runs right after suppression, inside `MutantDiscoveryStage`.

## Inactive `#if` branches

A mutant in a branch the host build leaves out — `#if os(Windows)`, `#if canImport(Glibc)`, the `#else` of `#if canImport(Darwin)` — compiles to nothing, so no test can reach it and it can only survive. `InactiveRegionExtractor` asks SwiftIfConfig, with `HostBuildConfiguration` describing the macOS build the tool runs, which clauses of each file are not active, and `InactiveRegionFilter` drops every point inside one. An `#if` the configuration cannot decide — a `canImport` of a module outside its curated lists — keeps all of its clauses: the filter errs towards keeping a mutant, never towards dropping a real one. It runs last in `MutantDiscoveryStage`, after the infinite-loop filter.

## Data Structures

```
DiscoveryInput
├── projectPath       — project root (Xcode or SPM)
├── projectType       — ProjectType (.xcode or .spm)
├── sourcesPath       — root for Swift file discovery
├── excludePatterns   — globs or path fragments to skip
├── operators         — list of active operator identifiers
└── timeout, concurrency, noCache

SourceFile
├── path              — absolute path to the .swift file
└── content           — raw source text

ParsedSource
├── file              — SourceFile
└── syntax            — SourceFileSyntax (SwiftSyntax AST)

MutationPoint
├── filePath          — absolute source file path
├── line, column      — 1-based position
├── utf8Offset        — byte offset in UTF-8 encoded content
├── originalText      — token(s) before mutation
├── mutatedText       — token(s) after mutation
├── operatorIdentifier
└── replacementKind   — ReplacementKind enum

IndexedMutationPoint
├── point             — MutationPoint
├── id                — unique ID (MutantID: swift-mutation-testing_<index>)
└── isSchematizable   — whether the mutation is inside a function body

MutantDescriptor
├── id                — unique ID
├── filePath          — absolute source file path
├── line, column      — 1-based position
├── utf8Offset        — byte offset
├── originalText      — token(s) before mutation
├── mutatedText       — token(s) after mutation
├── operatorIdentifier
├── replacementKind   — ReplacementKind enum
├── description       — human-readable mutation description
├── isSchematizable   — schematizable or incompatible
└── mutatedSourceContent — pre-computed full source (incompatible only)

RunnerInput
├── projectPath
├── projectType       — ProjectType (.xcode or .spm)
├── timeout, concurrency, noCache
├── schematizedFiles  — [SchematizedFile] (one per modified source file, each ending with its own support declarations)
└── mutants           — [MutantDescriptor] (all mutants, schematizable and incompatible)
```

---

← [Overview](01-overview.md) | Next: [Execution Pipeline →](03-execution.md)
