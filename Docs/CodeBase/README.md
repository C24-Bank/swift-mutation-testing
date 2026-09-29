# CodeBase Reference

Type-level reference for every public and internal type in `swift-mutation-testing`. Each document covers one module or cohesive group of types.

---

## Index

| Document | Coverage |
|---|---|
| [01 — Entry Point](01-entry-point.md) | `SwiftMutationTesting`, `ExitCode`, `HelpText`, `UsageError` |
| [02 — Configuration](02-configuration.md) | `CommandLineParser`, `ParsedArguments`, `RunnerConfiguration`, `BuildOptions`, `ReportingOptions`, `FilterOptions`, `ProjectType`, `TestingFramework`, `ConfigurationResolver`, `ConfigurationFileParser`, `ConfigurationFileWriter`, `ProjectDetector`, `DetectedProject` |
| [03 — Discovery Pipeline](03-discovery-pipeline.md) | `DiscoveryPipeline`, `DiscoveryInput`, `FileDiscoveryStage`, `FileDiscoveryError`, `ParsingStage`, `MutantDiscoveryStage`, `MutantIndexingStage`, `SchematizationStage`, `IncompatibleRewritingStage`, `SourceFile`, `ParsedSource`, `MutationPoint`, `IndexedMutationPoint`, `MutantDescriptor` |
| [04 — Mutation Operators](04-mutation-operators.md) | `MutationOperator`, `MutationSyntaxVisitor`, `ReplacementKind`, all 7 operator structs and visitors, `SuppressionAnnotationExtractor`, `SuppressionFilter`, `SuppressionVisitor` |
| [05 — Schematization](05-schematization.md) | `SchemataGenerator`, `MutationRewriter`, `TypeScopeVisitor`, `FunctionBodyScope`, `SchematizedFile` |
| [06 — Sandbox & Build](06-sandbox-build.md) | `SandboxFactory`, `Sandbox`, `BuildStage`, `BuildArtifact`, `BuildError` |
| [07 — Execution](07-execution.md) | `MutantExecutor`, `ExecutionDeps`, `TestExecutionStage`, `TestExecutionContext`, `TestLaunchResult`, `FallbackExecutor`, `IncompatibleMutantExecutor`, `SimulatorPool`, `SimulatorSlot`, `SimulatorManager`, `SimulatorError`, `MutationCounter`, `RunnerInput`, `ExecutionResult`, `ExecutionStatus` |
| [08 — Result Parsing & Cache](08-result-parsing-cache.md) | `TestResultResolver`, `ResultParser`, `SPMResultParser`, `TestRunOutcome`, `TestOutputParser`, `XCResultParser`, `CacheStore`, `MutantCacheKey` |
| [09 — Reporting & Infrastructure](09-reporting-infrastructure.md) | `ProgressReporter`, `ConsoleProgressReporter`, `SilentProgressReporter`, `RunnerEvent`, `RunnerSummary`, `TextReporter`, `JsonReporter`, `HtmlReporter`, `SonarReporter`, all `MutationReport*` types, all `Sonar*` types, `ProcessLaunching`, `ProcessRunner`, `ProcessRequest`, `SPMProcessLauncher`, `XCTestRunPlist`, `TestFilesHasher` |

---

## Quick Reference

### Value flow between pipelines

```
DiscoveryInput
  → FileDiscoveryStage        → [SourceFile]
  → ParsingStage              → [ParsedSource]
  → MutantDiscoveryStage      → [MutationPoint]
  → MutantIndexingStage       → [IndexedMutationPoint]
  → SchematizationStage       → [SchematizedFile], [MutantDescriptor]
  → IncompatibleRewritingStage → [MutantDescriptor]
  → RunnerInput

RunnerInput
  → SandboxFactory → Sandbox
  → BuildStage     → BuildArtifact
  → TestExecutionStage → TestResultResolver → [ExecutionResult]
  → FallbackExecutor (on build failure)     → [ExecutionResult]
  → IncompatibleMutantExecutor              → [ExecutionResult]
  → RunnerSummary
  → Reporters
```

### Actors

| Actor | Responsibility |
|---|---|
| `SimulatorPool` | Manages simulator slot availability |
| `CacheStore` | Serialises reads/writes to result cache |
| `MutationCounter` | Tracks progress index across concurrent tasks |
| `ConsoleProgressReporter` | Serialises progress output to stdout |

### Exit codes

| Code | Meaning |
|---|---|
| `0` | Success |
| `1` | Error (usage, build failure, unexpected) |

### Regions the suite deliberately does not cover

Region coverage is 98.7%. The regions left are listed here with the reason, so that the next person measuring does not spend a second afternoon rediscovering them. Everything not on this list is expected to be covered; a new uncovered region is a gap, not a member of this set.

Each entry was tried before it was listed. The rule from #95 applies: a region that cannot be made to fail under a negative control is a candidate for deletion, not for a test — five were deleted rather than covered (`MutantExecutor`'s probe guard, `RemoveSideEffectsVisitor`'s first-token guard, and three `?? false` fallbacks in `SandboxFactory` that became `== true`).

**Failure arms of system calls that macOS does not produce**

| file | line | call |
|---|---|---|
| `Infrastructure/ProcessTree.swift` | 32, 37 | `sysctl` fails |
| `Execution/MutantExecutor.swift` | 558 | `realpath` fails |
| `Infrastructure/SleepInhibitor.swift` | 17, 39 | the IOKit assertion table is absent or not a dictionary of arrays |
| `Infrastructure/TestFilesHasher.swift` | 30 | `FileManager.enumerator(at:)` returns `nil` |
| `Execution/TestBundleInvocation.swift` | 111, 115 | `xcode-select -p` fails to run, or prints nothing |
| `Infrastructure/XCTestRunPlist.swift` | 41 | a dictionary read from a plist cannot be written back as one |
| `Infrastructure/ProcessRunner.swift` | 145 | the temp file the runner itself created cannot be read back |

`FileManager.enumerator(at:)` was measured rather than assumed: it returns a non-`nil` enumerator for a regular file, a path that does not exist, and a directory the user cannot read. Covering these means injecting the syscall behind a protocol, which is a design change bought for one branch that returns a sane default.

**Guards an earlier check in the same function already makes impossible**

| file | line | why it cannot be reached |
|---|---|---|
| `Discovery/Pipeline/FileDiscoveryStage.swift` | 33 | `sourcesPath` was checked for existence five lines above, and the enumerator is never `nil` |
| `Discovery/Schematization/SchemataGenerator.swift` | 109 | `replaceRange` is called with the offsets `extract` has already accepted |
| `Discovery/Operators/ArithmeticOperatorVisitor.swift` | 50 | the operator is looked up by position in the list that contains it |
| `Infrastructure/XCTestRunPlist.swift` | 16 | `init?` already refused data that is not a `[String: Any]` |
| `Infrastructure/ProcessTree.swift` | 18 | the process table has no cycles, so no pid is visited twice |
| `Build/BuildStage.swift` | 100, 109 | both helpers are only ever passed the sandbox root, which exists |
| `Sandbox/SandboxFactory.swift` | 232 | same: `findXcodeproj` is only passed the sandbox root |

These stay because removing them replaces a graceful degrade with a crash or a force-unwrap. They are not free — each is a line that can rot without anyone noticing — which is why they are written down rather than left to be rediscovered.

**Race guards that cannot be provoked deterministically**

| file | line | what it protects |
|---|---|---|
| `Infrastructure/SPMProcessLauncher.swift` | 33 | `kill(-0, SIGTERM)` signals the tool's own process group. The guard fires when a run is cancelled before its process exists |
| `Infrastructure/XcodeProcessLauncher.swift` | 27 | same |
| `Simulator/SimulatorPool.swift` | 150 | a slot request cancelled after it was already resumed |

A test would have to win a race against `Process.run()`, and a flaky test costs more than the line it covers.

**The entry point**

| file | line | why |
|---|---|---|
| `Sandbox/SandboxCleaner.swift` | 4 | the default exit handler calls `_exit`, which would end the test process |
| `SwiftMutationTesting.swift` | 61, 72 | the `quiet` branch and the launcher default, both taken by every real invocation |
