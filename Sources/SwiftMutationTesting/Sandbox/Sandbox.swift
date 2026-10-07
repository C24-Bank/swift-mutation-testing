import Foundation

struct Sandbox: Sendable {
    struct OriginalFile: Sendable {
        let url: URL
        let content: Data?
    }

    let rootURL: URL
    let originals: [OriginalFile]
    let isInPlace: Bool

    init(rootURL: URL, originals: [OriginalFile] = [], isInPlace: Bool = false) {
        self.rootURL = rootURL
        self.originals = originals
        self.isInPlace = isInPlace
    }

    var derivedDataURL: URL {
        rootURL.appendingPathComponent(".xmr-derived-data")
    }

    var resultsURL: URL {
        guard isInPlace else { return rootURL }
        let url = rootURL.appendingPathComponent(".xmr-results")
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    func cleanup() throws {
        guard isInPlace else {
            try FileManager.default.removeItem(at: rootURL)
            return
        }

        for original in originals.reversed() {
            if let content = original.content {
                try content.write(to: original.url, options: .atomic)
            } else {
                try? FileManager.default.removeItem(at: original.url)
            }
        }
    }
}
