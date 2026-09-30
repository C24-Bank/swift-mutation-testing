# Schematization

← [Configuration](04-configuration.md) | [Index →](README.md)

---

## Purpose

Schematization is the key technique that allows `swift-mutation-testing` to run `xcodebuild build-for-testing` exactly once for all schematizable mutants. Instead of creating a separate binary per mutant, all mutations for a given function body are embedded into the same binary behind a runtime `switch` statement. The active mutant is selected at test time by setting an environment variable.

## Schematizable vs Incompatible Mutants

A mutation is **schematizable** when it falls inside a function body — anywhere `TypeScopeVisitor` can determine an enclosing function scope. Mutations outside function bodies (stored property initializers, global-scope expressions) are **incompatible** and require a separate full build + test cycle via `IncompatibleMutantExecutor`.

```mermaid
flowchart TD
    MP[MutationPoint] --> TSV[TypeScopeVisitor\ninnermostScope]
    TSV -- scope found --> SCHEMA[Schematizable\nembedded in switch]
    TSV -- no scope --> INCOMPAT[Incompatible\nfull rewrite per mutant]
```

## SchemataGenerator

`SchemataGenerator` rewrites each function body to contain a `switch __swiftMutationTestingID` block. Mutations are grouped by the innermost enclosing scope. For each group:

1. Extract the original statement text (from `statementsStartOffset` to `statementsEndOffset`)
2. For each mutant in the group, apply the mutation to produce a mutated copy of the statements
3. Build a `switch` block with one `case` per mutant and a `default` for the original code
4. Replace the function body `{...}` with the new `switch` block

```swift
{
    switch __swiftMutationTestingID {
    case "swift-mutation-testing_0":
        return a - b
    case "swift-mutation-testing_1":
        return a + b
    default:
        return a + b
    }
}
```

Mutant IDs follow the pattern `swift-mutation-testing_<index>`, where index is the global sequential position of the mutant across all files.

Multiple scopes within the same file are processed in reverse order by `bodyStartOffset` to preserve correct byte offsets as the content grows.

## MutationRewriter

For **incompatible** mutants, `MutationRewriter` applies the single mutation directly to the source file's raw text using UTF-8 byte offsets, producing a complete replacement source file stored in `MutantDescriptor.mutatedSourceContent`.

Both `MutationRewriter` and `SchemataGenerator` use force-unwrapped UTF-8 conversions (`data(using: .utf8)!`, `String(data:encoding: .utf8)!`) because Swift source code is guaranteed to be valid UTF-8. This avoids unreachable error-handling paths.

## TypeScopeVisitor

`TypeScopeVisitor` walks the SwiftSyntax AST and records every `FunctionBodyScope` — the UTF-8 byte range of each function body's `{`, its statements, and its closing `}`. It visits function declarations, initializers, deinitializers, and property/subscript accessors.

```
FunctionBodyScope
├── bodyStartOffset       — byte offset of opening {
├── bodyEndOffset         — byte offset after closing }
├── statementsStartOffset — byte offset of first statement
└── statementsEndOffset   — byte offset after last statement
```

`innermostScope(containing:)` returns the tightest scope that contains a given UTF-8 offset, enabling correct handling of nested functions and closures.

`isSchematizable(utf8Offset:)` is the Boolean interface used by `SchematizationStage` to classify each mutation point.

## Per-file support declarations

Every schematized file ends with the same block, appended by `SchemataGenerator` (`SupportDeclarations.perFile`):

```swift
import Foundation

private enum __SwiftMutationTesting {
    nonisolated static let id: String =
        ProcessInfo.processInfo.environment["__SWIFT_MUTATION_TESTING_ACTIVE"] ?? ""
}

nonisolated private var __swiftMutationTestingID: String { __SwiftMutationTesting.id }
```

Each piece of it is there for a reason:

- **`private`, once per file.** A single `internal` declaration in one module — what a shared `__SMTSupport.swift` used to be — is invisible to schematized files in any other module, so their schema did not compile and their mutants fell to one build each. A file-scope `private` declaration is visible exactly where the schema is, cannot clash with the same declaration in another file, and needs no file of its own — which also matters for Xcode projects, which compile only the files their `project.pbxproj` lists.
- **A `static let`, not a global.** A stored global declared in `main.swift` is initialized when top-level code reaches its line; a function called before that reads uninitialized memory and crashes. A static stored property is initialized on first use wherever it is declared, so the block can sit at the end of any file, `main.swift` included, without shifting the line numbers of the code above it.
- **Read once.** `ProcessInfo.processInfo.environment` builds a dictionary of the whole environment; reading it once per file, instead of on every function call, keeps the schema's cost to a string comparison.
- **`nonisolated`.** Under Swift 6.2's default `MainActor` isolation, which app targets opt into, an unmarked global or static is main-actor isolated and a nonisolated function cannot read it. Both declarations opt out, and the same block compiles in Swift 5 mode, Swift 6 mode and under default isolation.
- **`import Foundation` at the end.** An import may appear anywhere at file scope, and a repeated import is allowed, so the block needs no knowledge of what the file already imports.

The block is part of `SchematizedFile.schematizedContent`. That is what makes the retry after a failed schema build correct for free: the narrowed schema comes from the same generator and carries the same declarations.

## Runtime Activation

At test execution time, `XCTestRunPlist.activating(_:)` injects the mutant ID into the `.xctestrun` plist under `EnvironmentVariables.__SWIFT_MUTATION_TESTING_ACTIVE` for every test target in the run. A fresh copy of the `.xctestrun` is written for each mutant.

```mermaid
flowchart TD
    PLIST[BuildArtifact.plist] --> ACT[XCTestRunPlist.activating\nmutantID]
    ACT --> XCTESTRUN[Temporary .xctestrun\nwith env var set]
    XCTESTRUN --> XCB[xcodebuild test-without-building\n-xctestrun <path>]
    XCB --> BINARY[Test binary reads\n__SWIFT_MUTATION_TESTING_ACTIVE\nat startup]
    BINARY --> SWITCH[switch __swiftMutationTestingID\nroutes to active mutant]
```

When no environment variable is set (baseline run or passive execution), `__swiftMutationTestingID` returns `""`, which matches no `case` and the `default` branch executes — the original code runs unmodified.

## Empty Case Body Fix

Swift requires `case` blocks in `switch` statements to contain at least one statement. When a mutated statement set is empty (e.g. `RemoveSideEffects` removes the only statement in a function body), the generated `case` block would be empty and fail to compile. `SandboxFactory.fixEmptySwitchCaseBodies` post-processes schematized files and inserts a `break` statement into any empty `case "..."` block before the build runs.

---

← [Configuration](04-configuration.md) | [Index →](README.md)
