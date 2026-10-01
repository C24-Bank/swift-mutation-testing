import Foundation

struct TestTargetSelection: Sendable {
    let bundleURLs: [URL]
    let filter: String?

    static func make(target: String?, bundleURLs: [URL]) -> TestTargetSelection {
        guard let target, let own = bundleURLs.first(where: { TestBundle(url: $0, libraries: []).name == target })
        else { return TestTargetSelection(bundleURLs: bundleURLs, filter: target) }

        return TestTargetSelection(bundleURLs: [own], filter: nil)
    }
}
