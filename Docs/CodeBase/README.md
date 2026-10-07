# CodeBase Reference

Type-level reference for every public and internal type in `swift-mutation-testing`. Each document covers one module or cohesive group of types.

---

## Index

| Document | Coverage |
|---|---|
| [01 — Entry Point](01-entry-point.md) | `SwiftMutationTesting`, `Command` and its seven commands (`HelpCommand`, `VersionCommand`, `InitCommand`, `PlanCommand`, `MergeCommand`, `ReproduceCommand`, `RunCommand`), `RunConclusion`, `CommandSupport`, `ExitCode`, `HelpText`, `UsageError` |
| [02 — Configuration](02-configuration.md) | `CommandLineParser`, `ParsedArguments`, `RunnerConfiguration`, `BuildOptions`, `ReportingOptions`, `FilterOptions`, `ProjectType`, `XcodeContainer`, `XcodeContainerLocator`, `TestingFramework`, `ConfigurationResolver`, `ConfigurationFileParser`, `ConfigurationFileWriter`, `ProjectDetector`, `DetectedProject`, `GateOptions` |
| [03 — Discovery Pipeline](03-discovery-pipeline.md) | `DiscoveryPipeline`, `OperatorRegistry`, `OperatorTier`, `DiscoveryInput`, `FileDiscoveryStage`, `FileDiscoveryError`, `ParsingStage`, `MutantDiscoveryStage`, `MutantIndexingStage`, `SchematizationStage`, `IncompatibleRewritingStage`, `SourceFile`, `ParsedSource`, `MutationPoint`, `IndexedMutationPoint`, `MutantDescriptor`, `MutantID`, `MutationExclusion`, `DeclarationPath`, `MutantFingerprint` |
| [04 — Mutation Operators](04-mutation-operators.md) | `MutationOperator`, `OperatorVisitor`, `VisitorOperator`, `MutationSyntaxVisitor`, `ReplacementKind`, all 7 operator typealiases and visitors, `SuppressionAnnotationExtractor`, `SuppressionFilter`, `SuppressionVisitor`, `InfiniteLoopBodyVisitor`, `InfiniteLoopBodyExtractor`, `InfiniteLoopFilter`, `HostBuildConfiguration`, `InactiveRegionExtractor`, `InactiveRegionFilter` |
| [05 — Schematization](05-schematization.md) | `SchemataGenerator`, `SupportDeclarations`, `ActivationInstrumenter`, `ImportStyle`, `FunctionBodyShape`, `MutationRewriter`, `UTF8Splice`, `TypeScopeVisitor`, `FunctionBodyScope`, `SchematizedFile` |
| [06 — Sandbox & Build](06-sandbox-build.md) | `SandboxFactory`, `SandboxName`, `SandboxCleaner`, `OrphanedProcessReaper`, `SandboxRegistry`, `Sandbox`, `BuildStage`, `ToolRequests`, `BuildArtifact`, `BuildError` |
| [07 — Execution](07-execution.md) | `MutantExecutor`, `SchemaNarrower`, `BaselineProbe`, `ResultRecorder`, `ExecutionDeps`, `ApplicationVerifier`, `IntegrityError`, `ActivationMarker`, `TestExecutionStage`, `TestExecutionContext`, `TestBundle`, `TestTargetSelection`, `TargetedSuite`, `TestLaunchResult`, `TestBundleInvocation`, `DeveloperToolchain`, `TargetedSuites`, `FallbackExecutor`, `IncompatibleMutantExecutor`, `SimulatorPool`, `SimulatorSlot`, `SimulatorManager`, `SimulatorError`, `MutationCounter`, `RunnerInput`, `ExecutionResult`, `ExecutionStatus`, `BaselineError` |
| [08 — Result Parsing & Cache](08-result-parsing-cache.md) | `TestResultResolver`, `ResultParser`, `SPMResultParser`, `TestRunOutcome`, `TestOutputParser`, `XCResultParser`, `CacheStore`, `CacheTestSelection`, `MutantCacheKey`, `KillerTestFileResolver` |
| [09 — Reporting & Infrastructure](09-reporting-infrastructure.md) | `ProgressReporter`, `ConsoleProgressReporter`, `SilentProgressReporter`, `RunnerEvent`, `RunnerSummary`, `RunnerSummary+DetectionLine`, `RunnerSummary+Integrity`, `ExecutionResult+ReportStatusReason`, `ReportFormat`, `ReportWriter`, `TextReporter`, `JsonReporter`, `HtmlReporter`, `SonarReporter`, `SarifReporter`, all `Sarif*` types, `MarkdownReporter`, `GateResult+Summary`, `MutantLogWriter`, all `MutationReport*` types, all `Sonar*` types, `ProcessLaunching`, `ProcessRunner`, `ProcessRequest`, `OutputStopRule`, `OutputWatcher`, `SPMProcessLauncher`, `XcodeProcessLauncher`, `SleepInhibitor`, `StandardOutput`, `StandardError`, `FileSystem`, `VersionedJSON`, `JSONLines`, `SystemCalls`, `CanonicalPath`, `ProcessTree`, `ProcessArguments`, `TimeoutEscalation`, `ProcessGroupRegistry`, `XCTestRunPlist`, `TestFilesHasher`, `ProjectRelativePath` |
| [10 — Quality Gate](10-quality-gate.md) | `QualityGate`, `GatePolicy`, `GateResult`, `GateError`, `Baseline`, `BaselineScope`, `BaselineEntry`, `BaselineStore`, `GateReporter` |
| [11 — Plans](11-plans.md) | `Plan`, `PlanStore`, `PlanError`, `Planner`, `PlanMaterializer`, `PlanJournal`, `PlanResumer`, `Shard`, `ShardSelector`, `RunIdentity`, `RunnerConfiguration+Plan`, `ResultMerger`, `MergeError`, `Reproducer` |

---

## Quick Reference

### Value flow between pipelines

```
DiscoveryInput
  → FileDiscoveryStage        → [SourceFile]            ┐
  → ParsingStage              → [ParsedSource]          │ Planner
  → MutantDiscoveryStage      → [MutationPoint]         │
  → MutantIndexingStage       → [IndexedMutationPoint]  ┘ → Plan (+ plan.json through PlanStore)
  → SchematizationStage       → [SchematizedFile], [MutantDescriptor]  ┐ PlanMaterializer
  → IncompatibleRewritingStage → [MutantDescriptor]                     ┘
  → RunnerInput

RunnerInput
  → SandboxFactory → Sandbox
  → BuildStage     → BuildArtifact
  → TestExecutionStage → TestResultResolver → [ExecutionResult]
  → FallbackExecutor (on build failure)     → [ExecutionResult]
  → IncompatibleMutantExecutor              → [ExecutionResult]
  → RunnerSummary
  → ReportWriter → Reporters
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

Region coverage is 99.5% — nine regions of 1939. The regions left are listed here with the reason, so that the next person measuring does not spend a second afternoon rediscovering them. Everything not on this list is expected to be covered; a new uncovered region is a gap, not a member of this set.

Each entry was tried before it was listed. The rule from #95 applies: a region that cannot be made to fail under a negative control is a candidate for deletion, not for a test — five were deleted rather than covered (`MutantExecutor`'s probe guard, `RemoveSideEffectsVisitor`'s first-token guard, and three `?? false` fallbacks in `SandboxFactory` that became `== true`).

**Failure arms of system calls that macOS does not produce** — none left

This group used to hold ten regions: `sysctl` failing, `realpath` failing, `FileManager.enumerator(at:)` returning `nil`, `xcode-select -p` failing to run or printing bytes that are not text, the IOKit assertion table being absent or misshapen, a plist that cannot be written back, and the runner's own capture file being unreadable. `FileManager.enumerator(at:)` was measured rather than assumed: it returns a non-`nil` enumerator for a regular file, a path that does not exist, and a directory the user cannot read.

All ten are covered now, by the same move each time: the failing call is a parameter that defaults to the real call, so no production site changes, and the `try?`/`??` stays at the call site so a test can hand in a failing one and watch the arm fire. `ProcessRunner` takes the function that reads the capture file back; `XCTestRunPlist.activating` takes the serializer; `SleepInhibitor.isHeld` takes the function that fetches the assertion table; `TestFilesHasher` takes the enumerator; `ProcessTree.descendants` takes `sysctl`; `DeveloperToolchain.resolveDeveloperPath` takes the executable to run; and `realpath` moved out of `MutantExecutor` into `CanonicalPath.make(for:resolve:)`, which takes the resolver. The function typealiases live in `SystemCalls`. The same move covered the two launchers' `guard pid > 0` below.

**Guards an earlier check in the same function already makes impossible**

| file | line | why it cannot be reached |
|---|---|---|
| `Discovery/Pipeline/FileDiscoveryStage.swift` | 50 | `sourcesPath` was checked for existence at the top of `run`, and the enumerator is never `nil` |
| `Discovery/Operators/ArithmeticOperatorVisitor.swift` | 57 | the operator is looked up by position in the list that contains it |
| `Infrastructure/XCTestRunPlist.swift` | 23 | `init?` already refused data that is not a `[String: Any]` |
| `Infrastructure/ProcessTree.swift` | 18 | the process table has no cycles, so no pid is visited twice |
| `Build/BuildStage.swift` | 100, 109 | both helpers are only ever passed the sandbox root, which exists |
| `Sandbox/SandboxFactory.swift` | 232 | same: `xcodeprojs(in:)` is only passed the sandbox root |

These stay because removing them replaces a graceful degrade with a crash or a force-unwrap. They are not free — each is a line that can rot without anyone noticing — which is why they are written down rather than left to be rediscovered.

**Race guards that cannot be provoked deterministically** — none left

Three regions used to sit here: `guard pid > 0` in both launchers' timeout handlers, and `SimulatorPool.cancelPending` being asked to cancel a request that was already resumed. The launchers' guard is what stands between a run cancelled before its process exists and `kill(-0, SIGTERM)`, which would signal the tool's own process group; it is covered by handing the static `terminate(pid:…)` a recording `kill` and asserting that pid 0 sends nothing. `cancelPending` was simply made non-private so a test can call it with an id that was never queued, which is the one place on this page where coverage was bought with a visibility change rather than an injected call.

**The entry point**

| file | line | why |
|---|---|---|
| `Sandbox/SandboxCleaner.swift` | 13 | `SignalTarget.process` exits through `_exit`, which would end the test process |

Covering that one means running the binary as a child process, sending it `SIGINT` and asserting on the exit code and the sandbox it left behind — an integration test, not a unit test.
