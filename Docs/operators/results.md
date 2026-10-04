| Operator | Tier by the criteria | Projects (≥ 10 mutants) | Median kill rate | Unviable | Equivalent (reviewed) | Cost per mutant |
|---|---|---|---|---|---|---|
| `ArithmeticOperatorReplacement` | experimental | 3 of 4 | 92.1% | 14.8% | 61.5% (13) | 2189 ms |
| `BooleanLiteralReplacement` | default | 4 of 4 | 69.4% | 13.5% | 12.1% (33) | 2636 ms |
| `LogicalOperatorReplacement` | conservative | 3 of 4 | 87.5% | 0.0% | 8.3% (12) | 2384 ms |
| `NegateConditional` | conservative | 4 of 4 | 93.3% | 0.3% | 9.5% (21) | 1434 ms |
| `RelationalOperatorReplacement` | experimental | 4 of 4 | 83.9% | 8.8% | 34.8% (46) | 1720 ms |
| `RemoveSideEffects` | experimental | 4 of 4 | 65.9% | 1.2% | 45.2% (42) | 3475 ms |
| `SwapTernary` | conservative | 3 of 4 | 100.0% | 0.0% | 10.0% (10) | 1974 ms |

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
