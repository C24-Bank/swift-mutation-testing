# C24 fork of swift-mutation-testing

Fork of [ericodx/swift-mutation-testing](https://github.com/ericodx/swift-mutation-testing) at v1.5.1.
Upstream assumes a small project run from a developer's checkout. We run it against a large iOS
app (Xcode project, 34 local Swift packages, signed binary frameworks, ~35,000 unit tests) from a
disposable checkout. These changes make that work and make it fast.

Branch `prototype/bank-ios-trial` holds them as one commit per fix, unpolished. Options are
environment variables for now; they should become config keys before anything goes upstream.
Tried and removed: `-only-testing` on `build-for-testing` (it does not shrink the build; use a
package scheme), and a `-skip-testing` list (flaky tests are fixed in the tests, not worked around
here).

## Changes and why

| # | Change | Problem it solves |
| --- | --- | --- |
| 1 | Copy project files into the sandbox instead of symlinking them | Xcode rejects signed `.xcframework`s whose files are symlinks, so every build failed |
| 2 | Skip the project's `.git`; give each sandbox an empty throwaway repository | A worktree's `.git` points at the real repository, so build scripts in the sandbox rewrote its shared config (e.g. `core.hooksPath`). With no repository at all, scripts that call git fail and stop the build |
| 3 | `-collect-test-diagnostics never` on every test run | After a failing run, xcodebuild may run `simctl diagnose` for up to 600 s, turning killed mutants into timeouts |
| 4 | Pin the test plan (`SMT_TEST_PLAN`, also for out-of-body mutant builds); find the `.xctestrun` under custom build locations; prefer the pinned plan, else the newest | With a custom Xcode build location, products land outside `-derivedDataPath`. A scheme with several plans produces several `.xctestrun` files and the first one found was used |
| 5 | In-place mode (`SMT_IN_PLACE=1`) | Every sandbox started with empty DerivedData, so each build was cold (10+ min). In place, mutated files are written into the checkout and restored afterwards, and builds reuse its warm DerivedData |
| 6 | One `fileprivate` mutant-ID variable per schematized file | The single internal global changed the module's interface (testability), so every importer recompiled. It also broke the build when an out-of-body mutant replaced the file holding it |
| 7 | Treat shorthand getters (`var x: T { … }`) as schematizable scopes | They have no `AccessorDecl`, so every mutation in them needed its own build. On our app this cut out-of-body mutants from 33% to 0.7% |
| 8 | `--diff <git-ref>` (config `diff`): only mutate lines added or changed since the ref, compared with the working tree | Weekly or per-PR runs: last week's changes on our app are 130 mutants instead of 15,230. Without it, a full run as before |
| 9 | One test pass with exactly the configured `--timeout`; no doubled first pass, no retry pass | A hanging mutant cost 3× the timeout (one cost 20 min). With selected tests a run takes 5–37 s, so a fixed 60 s is enough and a hang costs exactly that |
| 10 | Timeouts count as detected in the score | A timeout means the tests reacted to the mutant, just slowly. On bank-ios all four timeouts at 60 s were real kills (assertions failing within 1 s while the run went on, or repeated crashes); counting them as undetected lowered the score from 93% to 87% |
| 11 | Remove `TestRepetitionPolicy` from each mutant's `.xctestrun` copy | A test plan with "retry on failure" (ours: up to 3 runs) re-ran every test a mutant broke, so each kill cost its failing tests three times. The plan itself stays unchanged for CI |
| 12 | The first mutant run on each simulator gets at least 5 min (5× the timeout), later runs the normal timeout | The first run on a fresh simulator clone also installs and first-launches the app (~45 s on our app), so with a 60 s timeout the first mutants timed out before any test ran, and a survivor counted as detected |
| 13 | Stop an Xcode test run at the first failing test or crash | xcodebuild ran on after a test had failed, and relaunched the test runner after each crash (one mutant: ~20 relaunches, 530 s). Kills now end within seconds; on 61 mutants the run went from 11.6 to 6.4 min with the same verdicts |

## Usage

```sh
SMT_IN_PLACE=1 \
SMT_TEST_PLAN=<plan> \
swift-mutation-testing . --sources-path <folder> --scheme <scheme> \
  --target "<TestTarget>[/<TestClass>]" --concurrency 4 --timeout 60 \
  [--diff origin/develop] \
  --exclude Page.swift --exclude View.swift --no-cache
```

- **In-place mode is only for disposable checkouts.** An interrupted run leaves mutated files
  behind (`git checkout .` restores them) plus `.xmr-derived-data/` and `.xmr-results/`.
- `--sources-path` must be a folder; a single file discovers nothing (upstream bug).
- Use only the conservative operators (`NegateConditional`, `LogicalOperatorReplacement`,
  `SwapTernary`). `init` enables all seven, and some arithmetic and boolean mutants don't compile,
  which breaks the shared build for every mutant.
- Exclude SwiftUI views: their `body` is a result builder and the generated `switch` there is risky.
- For an app scheme with snapshot or UI test targets, build with a dedicated scheme that lists only
  the unit test plan and testables: `build-for-testing` builds every testable in the scheme,
  whichever plan is selected.
- Never kill a run: simulator clones (`XMR-*`) are deleted only on normal exit, and the default
  concurrency is CPU count − 1.

## Known gaps

- No baseline check on the Xcode path: if the unmutated suite is red, every mutant counts as killed
  and the score reads 100%.
- One `--target` for all mutants; no per-mutant test selection yet.
- The killer is only the first failing test, and a flaky test can fake a kill.
- `TimeoutEscalationTests` (upstream, timing-based) can fail in a full `swift test` run under load;
  it passes on its own. Upstream v1.5.1 itself fails two fixture tests here that pass on this branch.

## Candidates for upstream

1, 2, 3, 4, 6 and 7 are general fixes. 5 (in-place) and 8 (diff) fit as opt-in config keys.
Single-file `--sources-path` is a separate small bug.
