# Operators

Every operator has a **tier**, and the tier comes from measured data, not from opinion. A run takes the operators up to a tier (`--operator-tier`, or `operator-tier` in the file; see [USAGE.MD](USAGE.MD#operator-tiers)): `conservative` is the smallest set, `default` is what runs when nothing is said, `experimental` holds every operator.

## Tiers

| Tier | Every criterion must hold |
|---|---|
| `conservative` | median kill rate ≥ 70%, unviable ≤ 5%, equivalent ≤ 10% |
| `default` | median kill rate ≥ 40%, unviable ≤ 15%, equivalent ≤ 25% |
| `experimental` | the rest, or insufficient data: fewer than 3 projects with at least 10 mutants of the operator |

The limits were proposed before any data existed. A campaign may show they need to move; every change is recorded under [Decisions](#decisions) with its reason. The first campaign moved one: a project qualifies with 10 mutants of an operator, not 30.

## Current tiers

Assigned on 2026-10-04 from the first campaign, by the criteria above:

| Tier | Operators | What it buys |
|---|---|---|
| `conservative` | `LogicalOperatorReplacement`, `NegateConditional`, `SwapTernary` | median kill rate ≥ 87%, no unviable mutant to speak of, one survivor in ten equivalent |
| `default` | the three above and `BooleanLiteralReplacement` | the everyday run and CI: 69% median kill rate, 12% equivalent, 13.5% unviable |
| `experimental` | `RelationalOperatorReplacement`, `RemoveSideEffects`, `ArithmeticOperatorReplacement` | the deep run, `--operator-tier experimental`, for when someone will read the survivors: high kill rates, but one survivor in three (`Relational`), two in five (`RemoveSideEffects`) or three in five (`Arithmetic`) is equivalent, and `Relational` alone is half of all mutants |

A run with no `operator-tier` takes `default`. Before this campaign every operator ran by default; a score computed then and one computed now are not comparable, and `Docs/USAGE.MD` says so.

## Results of the first campaign

Run on 2026-10-02, with `swift-mutation-testing 0.0.0-dev [arm64-macos26]` built from the commit of this document, swift-driver version: 1.168.6 Apple Swift version 6.4, on Apple M4 Max, Version 26.6.2 (Build 25G83). Every number below comes from [`operators/results.csv`](operators/results.csv) and [`operators/equivalence.csv`](operators/equivalence.csv), written by `aggregate` and `sample` over the reports of that run.

### Operators

| Operator | Tier by the criteria | Projects (≥ 10 mutants) | Median kill rate | Unviable | Equivalent (reviewed) | Cost per mutant |
|---|---|---|---|---|---|---|
| `ArithmeticOperatorReplacement` | experimental | 3 of 4 | 92.1% | 14.8% | 61.5% (13) | 2189 ms |
| `BooleanLiteralReplacement` | default | 4 of 4 | 69.4% | 13.5% | 12.1% (33) | 2636 ms |
| `LogicalOperatorReplacement` | conservative | 3 of 4 | 87.5% | 0.0% | 8.3% (12) | 2384 ms |
| `NegateConditional` | conservative | 4 of 4 | 93.3% | 0.3% | 9.5% (21) | 1434 ms |
| `RelationalOperatorReplacement` | experimental | 4 of 4 | 83.9% | 8.8% | 34.8% (46) | 1720 ms |
| `RemoveSideEffects` | experimental | 4 of 4 | 65.9% | 1.2% | 45.2% (42) | 3475 ms |
| `SwapTernary` | conservative | 3 of 4 | 100.0% | 0.0% | 10.0% (10) | 1974 ms |

The tier column is what the criteria give for the numbers in the row; the tiers in force are in [Current tiers](#current-tiers) below, with the decisions that led there.

### Projects

| Project | Commit | Mutants | Score | Killed / survived / timeouts / no coverage / unviable | Integrity warnings | Wall time |
|---|---|---|---|---|---|---|
| swift-algorithms | `87e50f483c` | 1121 | 86.6% | 857 / 121 / 30 / 16 / 97 | 0 | 16 min |
| swift-argument-parser | `6a52f32511` | 839 | 63.8% | 474 / 237 / 3 / 34 / 91 | 0 | 18 min |
| swift-log | `9c6fb14227` | 224 | 72.5% | 156 / 50 / 2 / 10 / 6 | 1 | 1 min |
| swift-mutation-testing | `94f41b5666` | 1395 | 100.0% | 1358 / 0 / 15 / 0 / 22 | 147 | 23 min |

`swift-cpd` is in the corpus but has no report: its suite fails before any mutation is applied, because its test helper looks the `swift-cpd` executable up through `Bundle.allBundles`, which finds no `.xctest` under `swiftpm-testing-helper`, and falls back to a path the current SwiftPM layout does not have. It returns to the campaign when a release of it fixes that lookup. There is no Xcode app in this first campaign.

### Review of survivors

Up to 20 survivors per (operator, project), drawn with seed 20261001, each read in its source and classified:

| Operator | Sampled | Equivalent | Not equivalent | Not measurable | Equivalent share |
|---|---|---|---|---|---|
| `ArithmeticOperatorReplacement` | 17 | 8 | 5 | 4 | 61.5% |
| `BooleanLiteralReplacement` | 36 | 4 | 29 | 3 | 12.1% |
| `LogicalOperatorReplacement` | 12 | 1 | 11 | 0 | 8.3% |
| `NegateConditional` | 25 | 2 | 21 | 2 | 8.7% |
| `RelationalOperatorReplacement` | 46 | 16 | 30 | 0 | 34.8% |
| `RemoveSideEffects` | 56 | 20 | 23 | 13 | 46.5% |
| `SwapTernary` | 10 | 1 | 9 | 0 | 10.0% |

*Not measurable* survivors sit in code the build leaves out — Windows, FreeBSD and Android branches of an `#if` — so no test on the machine of the campaign can reach them; they count neither for nor against the operator. Every verdict carries a one-line reason in the CSV.

### Per project and operator

| Project | Operator | Generated | Detected | Survived | No coverage | Unviable | Kill rate | Cost per mutant |
|---|---|---|---|---|---|---|---|---|
| swift-algorithms | `ArithmeticOperatorReplacement` | 154 | 139 | 8 | 4 | 3 | 92.1% | 1452 ms |
| swift-algorithms | `BooleanLiteralReplacement` | 64 | 24 | 7 | 0 | 33 | 77.4% | 4330 ms |
| swift-algorithms | `LogicalOperatorReplacement` | 16 | 14 | 1 | 1 | 0 | 87.5% | 4452 ms |
| swift-algorithms | `NegateConditional` | 190 | 184 | 2 | 3 | 1 | 97.4% | 1537 ms |
| swift-algorithms | `RelationalOperatorReplacement` | 589 | 434 | 87 | 8 | 60 | 82.0% | 1407 ms |
| swift-algorithms | `RemoveSideEffects` | 49 | 33 | 16 | 0 | 0 | 67.3% | 7178 ms |
| swift-algorithms | `SwapTernary` | 59 | 59 | 0 | 0 | 0 | 100.0% | 897 ms |
| swift-argument-parser | `ArithmeticOperatorReplacement` | 43 | 14 | 6 | 0 | 23 | 70.0% | 1654 ms |
| swift-argument-parser | `BooleanLiteralReplacement` | 121 | 60 | 44 | 5 | 12 | 55.0% | 2146 ms |
| swift-argument-parser | `LogicalOperatorReplacement` | 31 | 20 | 11 | 0 | 0 | 64.5% | 1924 ms |
| swift-argument-parser | `NegateConditional` | 190 | 153 | 31 | 5 | 1 | 81.0% | 2051 ms |
| swift-argument-parser | `RelationalOperatorReplacement` | 266 | 137 | 72 | 9 | 48 | 62.8% | 1969 ms |
| swift-argument-parser | `RemoveSideEffects` | 132 | 46 | 65 | 14 | 7 | 36.8% | 2326 ms |
| swift-argument-parser | `SwapTernary` | 56 | 47 | 8 | 1 | 0 | 83.9% | 1680 ms |
| swift-log | `ArithmeticOperatorReplacement` | 5 | 2 | 3 | 0 | 0 | 40.0% | 304 ms |
| swift-log | `BooleanLiteralReplacement` | 31 | 19 | 9 | 3 | 0 | 61.3% | 348 ms |
| swift-log | `LogicalOperatorReplacement` | 7 | 7 | 0 | 0 | 0 | 100.0% | 105 ms |
| swift-log | `NegateConditional` | 28 | 25 | 3 | 0 | 0 | 89.3% | 162 ms |
| swift-log | `RelationalOperatorReplacement` | 55 | 42 | 6 | 1 | 6 | 85.7% | 139 ms |
| swift-log | `RemoveSideEffects` | 93 | 60 | 27 | 6 | 0 | 64.5% | 869 ms |
| swift-log | `SwapTernary` | 5 | 3 | 2 | 0 | 0 | 60.0% | 247 ms |
| swift-mutation-testing | `ArithmeticOperatorReplacement` | 96 | 78 | 0 | 0 | 18 | 100.0% | 3876 ms |
| swift-mutation-testing | `BooleanLiteralReplacement` | 132 | 130 | 0 | 0 | 2 | 100.0% | 3188 ms |
| swift-mutation-testing | `LogicalOperatorReplacement` | 67 | 67 | 0 | 0 | 0 | 100.0% | 2341 ms |
| swift-mutation-testing | `NegateConditional` | 301 | 301 | 0 | 0 | 0 | 100.0% | 1100 ms |
| swift-mutation-testing | `RelationalOperatorReplacement` | 405 | 403 | 0 | 0 | 2 | 100.0% | 2189 ms |
| swift-mutation-testing | `RemoveSideEffects` | 327 | 327 | 0 | 0 | 0 | 100.0% | 4100 ms |
| swift-mutation-testing | `SwapTernary` | 67 | 67 | 0 | 0 | 0 | 100.0% | 3296 ms |

## Decisions

**2026-10-04 — first campaign.** Four projects with reports (`swift-algorithms`, `swift-argument-parser`, `swift-log`, this repository), 202 survivors reviewed.

- *Calibration: a project qualifies with 10 mutants of an operator, not 30.* The criteria asked for three projects with 30 mutants each; `LogicalOperatorReplacement` had them in two, because the `#if` conditions that inflated its count in `swift-log` stopped being mutants during this campaign. With 10, it is judged on three projects' data — 87.5% median kill rate, no unviable mutant, one equivalent in twelve — and lands in `conservative`. The other limits stayed as proposed.
- *The strict `default` limit (25% equivalent) was kept, and three operators left the default run.* Relaxing it to 50% would have kept `RelationalOperatorReplacement` and `RemoveSideEffects` in `default`, but their equivalents are systematic — `reserveCapacity(n ± 1)`, a `> 0` under a `!= 0` guard, a performance heuristic choosing between two paths with the same result, a dropped `hasher.combine` — and come back as survivors in every run. A default run that reports one false survivor in three is not a safe one, and `Relational` alone is more than half of the mutants of a typical project, so leaving it out also halves the run. They remain one flag away.
- *`ArithmeticOperatorReplacement` is `experimental`* on 61.5% equivalents (13 reviewed; `+ 1`/`- 1` in capacity hints and offsets) and 14.8% unviable.
- *Review verdicts are the reviewer's reading of the code, not an execution.* A doubt was resolved as *not equivalent*, which does not demote. 21 survivors were *not measurable*: branches of an `#if` the macOS build leaves out.
- *What the campaign changed in the tool.* Twelve defects in discovery and schematization were found and fixed before these numbers were taken; the report at a commit before them would not be comparable.
