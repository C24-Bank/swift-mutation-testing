import Foundation

struct OutputStopRule: Sendable, Equatable {
    let markers: [String]
    let exitCode: Int32

    func matches(_ text: String) -> Bool {
        markers.contains { text.contains($0) }
    }
}

extension OutputStopRule {
    static let firstTestFailure = OutputStopRule(markers: TestOutputParser.failureMarkers, exitCode: 1)
}
