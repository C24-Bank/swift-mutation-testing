struct SchemataGenerator: Sendable {
    func generate(
        source: ParsedSource, mutations: [(index: Int, point: MutationPoint)], importStyle: ImportStyle = .implicit
    ) -> SchemaGeneration {
        let visitor = TypeScopeVisitor()
        visitor.walk(source.syntax)

        var groupedByScope: [Int: (scope: FunctionBodyScope, mutations: [(index: Int, point: MutationPoint)])] = [:]
        var discarded: [MutationPoint] = []

        for entry in mutations {
            guard let scope = visitor.innermostScope(containing: entry.point.utf8Offset) else {
                discarded.append(entry.point)
                continue
            }

            groupedByScope[scope.bodyStartOffset, default: (scope: scope, mutations: [])].mutations
                .append(entry)
        }

        let sortedGroups = groupedByScope.values.sorted {
            $0.scope.bodyStartOffset > $1.scope.bodyStartOffset
        }

        var content = source.file.content
        var edits = Edits()

        for group in sortedGroups {
            let scope = group.scope
            let statementsStart = edits.current(scope.statementsStartOffset)

            guard
                let originalStatements = UTF8Splice.substring(
                    of: content, from: statementsStart, to: edits.current(scope.statementsEndOffset)
                )
            else {
                discarded += group.mutations.map(\.point)
                continue
            }

            let sortedMutations = group.mutations.sorted { $0.index < $1.index }
            var cases: [(id: String, statements: String)] = []

            for entry in sortedMutations {
                guard
                    let mutated = apply(
                        entry.point,
                        to: originalStatements,
                        at: edits.current(entry.point.utf8Offset) - statementsStart
                    )
                else {
                    discarded.append(entry.point)
                    continue
                }
                cases.append((id: mutantID(entry.index), statements: mutated))
            }

            guard !cases.isEmpty else { continue }

            let switchBody = buildSwitchBody(
                cases: cases, defaultStatements: originalStatements, shape: scope.shape, path: source.file.path
            )
            content =
                UTF8Splice.replacing(
                    from: edits.current(scope.bodyStartOffset),
                    to: edits.current(scope.bodyEndOffset),
                    in: content,
                    with: switchBody
                ) ?? content
            edits.record(
                start: scope.bodyStartOffset,
                delta: switchBody.utf8.count - (scope.bodyEndOffset - scope.bodyStartOffset)
            )
        }

        guard content != source.file.content else {
            return SchemaGeneration(content: content, discarded: discarded)
        }

        var support = SupportDeclarations.perFile(for: source.file.path)
        if !ImportStyle.importsFoundation(source.syntax) {
            support = SupportDeclarations.importLine(importStyle) + "\n\n" + support
        }
        return SchemaGeneration(content: content + "\n\n" + support + "\n", discarded: discarded)
    }

    private struct Edits {
        private var deltas: [(start: Int, delta: Int)] = []

        func current(_ originalOffset: Int) -> Int {
            deltas.filter { $0.start < originalOffset }.reduce(originalOffset) { $0 + $1.delta }
        }

        mutating func record(start: Int, delta: Int) {
            deltas.append((start: start, delta: delta))
        }
    }

    private func mutantID(_ index: Int) -> String {
        "swift-mutation-testing_\(index)"
    }

    private func apply(_ mutation: MutationPoint, to statementsText: String, at relativeOffset: Int) -> String? {
        UTF8Splice.replacing(
            from: relativeOffset,
            to: relativeOffset + mutation.originalText.utf8.count,
            in: statementsText,
            with: mutation.mutatedText
        )
    }

    private func buildSwitchBody(
        cases: [(id: String, statements: String)],
        defaultStatements: String,
        shape: FunctionBodyShape,
        path: String
    ) -> String {
        var result = "{\n"
        result += "switch \(SupportDeclarations.identifier(for: path)) {\n"

        for (id, statements) in cases {
            result += "case \"\(id)\":\n\(caseBody(statements, shape: shape, path: path))\n"
        }

        result += "default:\n\(defaultBody(defaultStatements, shape: shape))\n"
        result += "}\n}"

        return result
    }

    private func caseBody(_ statements: String, shape: FunctionBodyShape, path: String) -> String {
        let activation = SupportDeclarations.activationCall(for: path)
        let isBlank = statements.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

        switch shape {
        case .expression where !isBlank:
            return "(\(activation), \(statements)).1"
        case .conditional(returnsValue: true):
            return "let _ = \(activation)\nreturn \(statements)"
        case .expression, .conditional, .statements:
            return "let _ = \(activation)\n\(statements)"
        }
    }

    private func defaultBody(_ statements: String, shape: FunctionBodyShape) -> String {
        shape == .conditional(returnsValue: true) ? "return \(statements)" : statements
    }
}
