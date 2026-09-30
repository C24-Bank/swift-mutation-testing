---
name: swift-mutation-testing
description: Run mutation testing on a Swift package or Xcode project with swift-mutation-testing, read the report, and write the tests that kill surviving mutants. Use when the user asks how good their Swift tests really are, whether the tests would catch a bug, where assertions are weak or missing, what the mutation score is, or asks to run swift-mutation-testing.
---

# Swift mutation testing

`swift-mutation-testing` changes the code under test in small ways — `<` to `<=`, `true` to `false`, a call removed — and runs the test suite once per change. Each change is a *mutant*. A mutant the tests catch is **killed**. A mutant no test notices **survived**: the code can be wrong in that exact way and the suite still passes. Coverage says a line ran; a survivor says nothing checked what it did.

The project is never modified. Every build and test run happens in a copy under `$TMPDIR/swift-mutation-testing/`.

Reference, when a detail here is not enough: [Usage](https://github.com/ericodx/swift-mutation-testing/blob/main/Docs/USAGE.MD) and [Mutation results](https://github.com/ericodx/swift-mutation-testing/blob/main/Docs/MUTATION-RESULTS.md).

## 1. Preconditions

1. **The tool is installed.** Run `swift-mutation-testing --version`. If it is missing, ask the user before installing it with `brew tap ericodx/homebrew-tools && brew install swift-mutation-testing`. It needs macOS 15+ and Swift 6.2+.
2. **The suite passes without mutations.** A suite that already fails kills every mutant, and the score means nothing.
   - Swift package: the tool checks this itself and stops with the failing tests named. Fix those first.
   - Xcode project: the tool does **not** check it. Run the tests yourself first (`xcodebuild test` with the same scheme and destination) and stop if they fail.
3. **The run is not in a hurry.** The suite runs once per mutant. On a package with a two-second suite and 300 mutants, expect minutes. On an app, expect much longer. Tell the user what you are about to start, and narrow the scope (step 2) when the project is large.

## 2. First run

If the project has no `.swift-mutation-testing.yml`, generate one:

```bash
swift-mutation-testing init <project-path>
```

`init` detects the project type, the scheme and destination (Xcode), the test target and the testing library. Read the generated file and check the scheme, the destination and `test-target` before running. Skip `init` when the file already exists: it holds the user's settings.

Always write the JSON report, because the text summary is for people and the JSON is what you read:

```bash
swift-mutation-testing <project-path> --output mutation-report.json
```

A Swift package needs no scheme or destination. An Xcode project needs both, in the file or as `--scheme` and `--destination "platform=macOS"` (or a simulator destination).

Narrowing the scope:

| Goal | How |
|---|---|
| One module or folder | `--sources-path Sources/MyModule` — a **directory**. A single file finds 0 mutants and reports 100% |
| Skip generated or vendored code | `--exclude /Generated/` — matched as a plain substring of the file path, not as a glob; repeatable |
| A few operators | `--operator RelationalOperatorReplacement --operator NegateConditional` |
| One test target | `--target MyPackageTests` |

Test files (`Tests/`, `*Tests.swift`, `Mocks/`, `.build/`) are never mutated.

A second run on unchanged code is fast: verdicts are cached in `.swift-mutation-testing-cache/`, keyed by file contents. Editing a source file re-tests that file's mutants; editing a test file re-tests the mutants that survived, and the killed ones whose killing test lives in that file. Use `--no-cache` only to rule out the cache when a result looks wrong.

## 3. Reading the result

The text summary ends with:

```
Overall mutation score: 85.3%
Detected: 122 (killed 122, timeout 0) / Undetected: 21 (survived 21, no coverage 0)
Killed: 122 / Survived: 21 / Timeouts: 0 / Unviable: 4 / NoCoverage: 0
```

```
detected   = killed + timeouts
undetected = survived + noCoverage
score      = detected / (detected + undetected) × 100
```

Each mutant in the JSON report (`files["/Sources/Foo.swift"].mutants[]`) carries `mutatorName`, `originalText`, `replacement`, `location.start.line` and `.column` (both 1-based), `status`, `killedBy` when a test killed it, and a `fingerprint` that identifies the mutant across runs. Its `status` is one of:

| `status` | Meaning | Action |
|---|---|---|
| `Killed` | A test failed with the mutant active. `statusReason: "crash"` means the process crashed instead | None |
| `Timeout` | The suite never finished, even when rerun alone. Counts as detected | None, unless there are many: check `--timeout` |
| `Survived` | The suite passed with the mutant active | **Write a test** (step 5) |
| `NoCoverage` | No test ran the mutated code | Write a test that reaches the code first |
| `CompileError` | The mutant did not compile | None. It is a property of the operator, not of the tests, and it is outside the score |

A 100% score means every mutant that compiled was detected. It does not mean the code is right.

## 4. Prioritizing

Work through the undetected mutants in this order:

1. **`NoCoverage` before `Survived`.** A whole path is untested, which is worse than a weak assertion.
2. **Group by file, then by function.** Several survivors in one function usually share one missing test: a boundary never checked, a branch never taken, a return value never asserted.
3. **One operator surviving repeatedly in one function is one cause.** `RelationalOperatorReplacement` surviving on `>=` and `>` at the same line means the boundary value is never tested.
4. **Business logic before glue.** A survivor in a pricing rule matters more than one in a log message.

What each operator's survivor usually means:

| Operator | A survivor usually means |
|---|---|
| `RelationalOperatorReplacement` | The boundary value (`x == limit`) is not tested |
| `BooleanLiteralReplacement` | A flag's effect is not asserted |
| `LogicalOperatorReplacement` | Only cases where both sides agree are tested |
| `ArithmeticOperatorReplacement` | The computed value is not asserted exactly |
| `NegateConditional` | Only one side of the branch is tested |
| `SwapTernary` | Both results of the ternary are never compared |
| `RemoveSideEffects` | The call's effect (state change, callback, write) is not verified |

## 5. Killing a survivor

1. Open the file at `location.start.line`. Apply `originalText` → `replacement` in your head and say what behavior changes.
2. Find the existing tests for that code, and use the library they use (XCTest or Swift Testing).
3. Write a test that **fails with the mutation and passes without it**: an input that reaches the line, and an assertion on the exact value or effect that the mutation changes.
4. Run the normal test suite. The new test must pass on the unmutated code.
5. Rerun the tool on the directory that holds the file (`--sources-path`), with `--output`. Confirm the mutant now reports `Killed` and `killedBy` names your test.

Never make a survivor go away by changing production code to avoid the mutation, by weakening an operator, or by excluding the file. The survivor is information about the tests, and the fix belongs in the tests.

When a test fails in a way you do not understand, rerun with `--keep-logs <dir>`: each mutant's full test output lands in `<dir>/<mutant-id>.log`.

## 6. Mutants that cannot be killed

Some survivors are **equivalent**: the mutation does not change observable behavior (for example `a > b ? a : b` → `a >= b ? a : b`: when `a == b` both return the same value). No test can kill them. Tell the user which ones you believe are equivalent and why, rather than writing a meaningless test.

To keep code out of the run, prefer `--exclude` (or `exclude:` in the config file) for generated and vendored code. The documentation also describes an `@SwiftMutationTestingDisabled` attribute, but Swift rejects it as an unknown attribute unless the project declares it, so do not add it to a declaration without first confirming the project builds with it.

## 7. Continuous integration

- Commit `.swift-mutation-testing.yml` so CI runs with no extra flags: `swift-mutation-testing --quiet --output mutation-report.json`.
- Cache `.swift-mutation-testing-cache/` between runs (`actions/cache`), keyed on the Swift sources and tests.
- Exit codes: `0` the run completed (and the quality gate passed, if set); `1` an error (bad arguments, a build that failed, a suite that fails without mutations, an unusable baseline); `2` the quality gate failed. On `2` the reports were still written.
- **Quality gate.** Suggest one when the user wants CI to fail on weak tests:
  - `--min-score 80` (or `min-score: 80` in the config file): fail below a score.
  - For a project that already has survivors, record them once and fail only on new ones:
    ```bash
    swift-mutation-testing --write-baseline .swift-mutation-testing-baseline.json   # commit this file
    swift-mutation-testing --baseline .swift-mutation-testing-baseline.json --max-new-survivors 0
    ```
  - `--max-score-drop 2` with `--baseline`: fail when the score falls more than 2 points below the baseline's.
  - Mutants are matched by fingerprint (file, enclosing declaration, operator, change), so edits elsewhere do not make old survivors look new. Renaming the function or editing the mutated expression does.
  - After killing survivors, write the baseline again so the fixed ones leave it. Never write a new baseline just to make a failing gate pass without telling the user which survivors it accepts.
- `--sonar-output` writes survivors as SonarQube external issues; `--html-output` writes a report for people.

## 8. Pitfalls

- **Do not compare scores across scopes.** A run with `--operator`, `--sources-path` or `--exclude` scores a different set of mutants than a full run.
- **A baseline only compares with the same scope.** A run whose operators, `--sources-path` or `--exclude` differ from the baseline's stops with exit code `1` and lists the differences. Run with the baseline's scope, or write a new baseline on purpose.
- **One run per project at a time.** Two runs on the same project write the same cache.
- **Xcode needs a destination that exists.** An iOS simulator destination must name an installed simulator; for code that runs on macOS, `platform=macOS` is faster and needs no simulator.
- **Timeouts cost time.** Each one waits for `--timeout` (30 s for packages, 120 s for Xcode by default), and it is rerun once alone before it is reported.
- **Do not leave the reports in the repository** unless the user asks: add `mutation-report.json` and `.swift-mutation-testing-cache/` to `.gitignore`.
