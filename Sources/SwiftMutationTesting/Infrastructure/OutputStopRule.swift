import Foundation

struct OutputStopRule: Sendable, Equatable {
    enum Line: Sendable, Equatable {
        case testFailure
    }

    let line: Line
    let exitCode: Int32

    func matches(_ text: String) -> Bool {
        text.split(separator: "\n").contains(where: stops(at:))
    }

    private func stops(at line: Substring) -> Bool {
        switch self.line {
        case .testFailure:
            return TestOutputParser().failingTest(in: String(line)) != nil
        }
    }
}

extension OutputStopRule {
    static let firstTestFailure = OutputStopRule(line: .testFailure, exitCode: 1)
}
