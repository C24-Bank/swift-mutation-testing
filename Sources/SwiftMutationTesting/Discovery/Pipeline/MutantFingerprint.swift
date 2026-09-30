import CryptoKit
import Foundation

enum MutantFingerprint {
    static func make(relativePath: String, declarationPath: String, mutation: MutationPoint, ordinal: Int) -> String {
        let components = [
            relativePath,
            declarationPath,
            mutation.operatorIdentifier,
            mutation.originalText,
            mutation.mutatedText,
            String(ordinal),
        ]
        let digest = SHA256.hash(data: Data(components.joined(separator: "\u{0}").utf8))
        return digest.prefix(16).map { String(format: "%02x", $0) }.joined()
    }
}
