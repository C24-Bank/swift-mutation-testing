struct MutationRewriter: Sendable {
    func rewrite(source: String, applying mutation: MutationPoint) -> String {
        let offset = mutation.utf8Offset
        let end = offset + mutation.originalText.utf8.count
        return UTF8Splice.replacing(from: offset, to: end, in: source, with: mutation.mutatedText) ?? source
    }
}
