import Foundation

struct MutantCacheKey: Hashable, Sendable, Codable {
    let filePath: String
    let fileContentHash: String
    let operatorIdentifier: String
    let utf8Offset: Int
    let originalText: String
    let mutatedText: String

    static func hash(of content: String) -> String {
        VersionedJSON.sha256(of: Data(content.utf8))
    }

    static func make(for mutant: MutantDescriptor) -> MutantCacheKey {
        MutantCacheKey(
            filePath: mutant.filePath,
            fileContentHash: mutant.sourceContentHash,
            operatorIdentifier: mutant.operatorIdentifier,
            utf8Offset: mutant.utf8Offset,
            originalText: mutant.originalText,
            mutatedText: mutant.mutatedText
        )
    }
}
