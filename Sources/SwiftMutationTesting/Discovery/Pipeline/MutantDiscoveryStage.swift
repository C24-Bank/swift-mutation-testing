struct MutantDiscoveryStage: Sendable {
    let operators: [any MutationOperator]

    private let suppressionExtractor = SuppressionAnnotationExtractor()
    private let suppressionFilter = SuppressionFilter()
    private let loopExtractor = InfiniteLoopBodyExtractor()
    private let loopFilter = InfiniteLoopFilter()
    private let regionExtractor = InactiveRegionExtractor()
    private let regionFilter = InactiveRegionFilter()

    init(operators: [any MutationOperator]) {
        self.operators = operators
    }

    func run(sources: [ParsedSource]) async -> [MutationPoint] {
        let allMutations = await withTaskGroup(of: [MutationPoint].self) { group in
            for source in sources {
                group.addTask {
                    self.mutationPoints(for: source)
                }
            }

            var collected: [MutationPoint] = []

            for await mutations in group {
                collected.append(contentsOf: mutations)
            }

            return collected
        }

        return allMutations.sorted {
            if $0.filePath != $1.filePath {
                return $0.filePath < $1.filePath
            }

            return $0.utf8Offset < $1.utf8Offset
        }
    }

    private func mutationPoints(for source: ParsedSource) -> [MutationPoint] {
        let suppressedRanges = suppressionExtractor.extractSuppressedRanges(from: source.syntax)
        let loopBodyRanges = loopExtractor.extractLoopBodyRanges(from: source.syntax)
        let inactiveRanges = regionExtractor.extractInactiveRanges(from: source.syntax)
        let mutations = operators.flatMap { $0.mutations(in: source) }
        let afterSuppression = suppressionFilter.filter(mutations, suppressedRanges: suppressedRanges)
        let afterLoops = loopFilter.filter(afterSuppression, loopBodyRanges: loopBodyRanges)
        return regionFilter.filter(afterLoops, inactiveRanges: inactiveRanges)
    }
}
