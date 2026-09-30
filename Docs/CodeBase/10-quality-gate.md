# Quality Gate

← [Reporting & Infrastructure](09-reporting-infrastructure.md) | [Index →](README.md)

---

The gate turns a run's result into a pass or fail. It runs after every report has been written, and a failed gate ends the run with `ExitCode.gateFailed` (`2`). It is inactive — and the run behaves as it did before the gate existed — unless a policy or a baseline is configured. The user-facing flow is in [Usage — Quality Gate](../USAGE.MD#quality-gate).

```mermaid
flowchart TD
    CFG[RunnerConfiguration.gate] --> LOAD{baselinePath?}
    LOAD -- yes --> READ[BaselineStore.read]
    READ --> SCOPE{BaselineScope\ndifferences?}
    SCOPE -- yes --> ERR[GateError.scopeMismatch → exit 1]
    SCOPE -- no --> RUN[run mutants, text summary]
    LOAD -- no --> RUN
    RUN --> EVAL[QualityGate.evaluate]
    EVAL --> REPORTS[write reports\nMarkdown includes the gate]
    REPORTS --> REP[GateReporter.report]
    REP --> WRITE{writeBaselinePath?}
    WRITE -- yes --> STORE[BaselineStore.write]
    WRITE -- no --> CODE
    STORE --> CODE[.success or .gateFailed]
```

The baseline is read and its scope checked before discovery, so a run that could never be compared stops before it spends any time.

---

## Gate/GatePolicy.swift

```swift
struct GatePolicy: Sendable, Equatable {
    var minScore: Double?
    var maxScoreDrop: Double?
    var maxNewSurvivors: Int?
    var isEmpty: Bool { get }
}
```

The three policies, each optional. `maxScoreDrop` and `maxNewSurvivors` need a baseline; `ConfigurationResolver` rejects them without one.

---

## Gate/QualityGate.swift

```swift
struct QualityGate: Sendable {
    func evaluate(_ summary: RunnerSummary, policy: GatePolicy, baseline: Baseline?) -> GateResult
}
```

| Policy | Check | Fails when |
|---|---|---|
| `minScore` | `.minScore(score:minimum:)` | `summary.score < minScore` |
| `maxScoreDrop` | `.scoreDrop(drop:maximum:)` | `baseline.score − summary.score > maxScoreDrop` |
| `maxNewSurvivors` | `.newUndetected(count:maximum:)` | undetected mutants whose fingerprint is not in the baseline number more than `maxNewSurvivors` |

"Undetected" is `RunnerSummary.undetected` — survived and no coverage — so a new mutant without coverage counts as a new survivor. Timeouts are detected, as in the score. A check that needs a baseline is skipped when there is none.

With a baseline, the result also lists the new undetected mutants, sorted by file and line, and counts the baseline's mutants that are no longer undetected (`fixedCount`). Both are informational.

---

## Gate/GateResult.swift

```swift
struct GateResult: Sendable {
    let checks: [Check]
    let newUndetected: [ExecutionResult]
    let fixedCount: Int?
    var passed: Bool { get }

    enum Check: Sendable, Equatable {
        case minScore(score: Double, minimum: Double)
        case scoreDrop(drop: Double, maximum: Double)
        case newUndetected(count: Int, maximum: Int)
        var passed: Bool { get }
    }
}
```

The gate passes when every check passes; with no checks it passes. `fixedCount` is `nil` without a baseline.

---

## Gate/Baseline.swift, BaselineScope.swift, BaselineEntry.swift

```swift
struct Baseline: Sendable, Codable, Equatable {
    static let formatVersion: Int  // 1
    let formatVersion: Int
    let toolVersion: String
    let createdAt: Date
    let score: Double
    let scope: BaselineScope
    let undetected: [BaselineEntry]

    init(summary: RunnerSummary, scope: BaselineScope, projectPath: String, toolVersion: String, createdAt: Date)
}

struct BaselineScope: Sendable, Codable, Equatable {
    let operators: [String]
    let sourcesPath: String
    let excludePatterns: [String]

    init(configuration: RunnerConfiguration)
    func differences(from other: BaselineScope) -> [String]
}

struct BaselineEntry: Sendable, Codable, Equatable {
    let fingerprint: String
    let file: String
    let line: Int
    let operatorIdentifier: String  // encoded as "operator"
    let original: String
    let replacement: String
    let status: String              // "survived" or "noCoverage"
}
```

A baseline is the undetected mutants of one run, meant to be committed. Entries are sorted by file, line and fingerprint, and `BaselineStore` writes sorted keys, so its diff in a pull request is stable and readable. The gate reads only `fingerprint`; `file`, `line`, `operator`, `original` and `replacement` are there for the people reviewing the diff.

`BaselineScope(configuration:)` records what the run covered: the operators (all of them when none is selected), the sources path relative to the project (`.` for the project itself), and the `exclude` patterns, with both lists sorted. `differences(from:)` names every field that differs, and a non-empty result stops the run: a different scope turns out-of-scope mutants into "new survivors", or hides real ones.

---

## Gate/BaselineStore.swift

```swift
struct BaselineStore: Sendable {
    func read(from path: String) throws -> Baseline
    func write(_ baseline: Baseline, to path: String) throws
}
```

Writes pretty-printed JSON with sorted keys, ISO 8601 dates and a trailing newline, atomically. Reading follows the same versioning discipline as `CacheStore`: it decodes `formatVersion` first, and throws `GateError.unsupportedBaselineVersion` for any version but `Baseline.formatVersion`, before trying the rest of the file.

---

## Gate/GateError.swift

```swift
enum GateError: Error, Equatable, LocalizedError {
    case baselineNotFound(path: String)
    case unreadableBaseline(path: String)
    case unsupportedBaselineVersion(path: String, version: Int)
    case scopeMismatch(path: String, differences: [String])
}
```

Every case ends the run with exit code `1`, and each description says how to recover — usually by writing a new baseline with `--write-baseline`.

---

## Reporting/GateReporter.swift

```swift
struct GateReporter: Sendable {
    static let listedLimit: Int  // 20
    let projectRoot: String
    func report(_ result: GateResult)
    func format(_ result: GateResult) -> String
}
```

Prints the gate after the text summary:

```
Quality gate: FAILED
  ✗ 2 new undetected mutants (max 0)
      Sources/Parser.swift:88   RelationalOperatorReplacement   < → <=
      Sources/Cache.swift:12    RemoveSideEffects               remove store()
  ✓ score 90.4% ≥ 85.0%
  ✓ score drop 0.7 pts ≤ 2.0 pts
  ℹ 3 mutants detected now that were undetected in the baseline
```

The wording of each check comes from `GateResult+Summary`, which `MarkdownReporter` shares. New undetected mutants are listed under their check, at most `listedLimit` of them, followed by `and N more — see the report`. With a baseline but no `maxNewSurvivors`, they are reported as an `ℹ` count instead.

---

← [Reporting & Infrastructure](09-reporting-infrastructure.md) | [Index →](README.md)
