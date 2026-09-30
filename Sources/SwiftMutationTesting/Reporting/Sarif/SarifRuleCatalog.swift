enum SarifRuleCatalog {
    static let helpUri =
        "https://github.com/ericodx/swift-mutation-testing/blob/main/Docs/USAGE.MD#operator-identifiers"

    static func rule(for operatorIdentifier: String) -> SarifRule {
        let (name, change) = descriptions[operatorIdentifier] ?? (operatorIdentifier, "Mutates the code.")
        return SarifRule(
            id: operatorIdentifier,
            name: operatorIdentifier,
            shortDescription: SarifMessage(text: name),
            fullDescription: SarifMessage(text: change),
            helpUri: helpUri,
            defaultConfiguration: SarifConfiguration(level: "warning")
        )
    }

    // MARK: - Private

    private static let descriptions: [String: (String, String)] = [
        "RelationalOperatorReplacement": (
            "Relational operator replacement",
            "Replaces a relational operator (>, >=, <, <=, ==, !=) with a neighbouring one. "
                + "A survivor usually means a boundary value is not tested."
        ),
        "BooleanLiteralReplacement": (
            "Boolean literal replacement",
            "Replaces true with false and false with true. A survivor usually means a flag's effect is not asserted."
        ),
        "LogicalOperatorReplacement": (
            "Logical operator replacement",
            "Replaces && with || and || with &&. A survivor usually means only cases where both sides agree are tested."
        ),
        "ArithmeticOperatorReplacement": (
            "Arithmetic operator replacement",
            "Replaces an arithmetic operator (+, -, *, /, %) with another. "
                + "A survivor usually means the computed value is not asserted exactly."
        ),
        "NegateConditional": (
            "Negate conditional",
            "Wraps a condition in !(...). A survivor usually means only one side of the branch is tested."
        ),
        "SwapTernary": (
            "Swap ternary",
            "Swaps the two results of a ternary expression. A survivor usually means they are never told apart."
        ),
        "RemoveSideEffects": (
            "Remove side effects",
            "Removes a standalone call statement. A survivor usually means the call's effect is not verified."
        ),
    ]
}
