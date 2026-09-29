import Foundation
import Testing

@testable import SwiftMutationTesting

@Suite("CanonicalPath")
struct CanonicalPathTests {

    @Test("Given a path the resolver cannot resolve, when made canonical, then it comes back unchanged")
    func anUnresolvablePathComesBackUnchanged() {
        #expect(CanonicalPath.make(for: "/some/where", resolve: { _ in nil }) == "/some/where")
    }

    @Test("Given a resolver that answers, when made canonical, then its answer is used and freed")
    func aResolvedPathIsUsed() {
        let result = CanonicalPath.make(for: "/some/where", resolve: { _ in strdup("/real/where") })

        #expect(result == "/real/where")
    }

    @Test("Given a symlink, when made canonical with the real resolver, then the target comes back")
    func aSymlinkResolvesToItsTarget() throws {
        let dir = try FileHelpers.makeTemporaryDirectory()
        defer { FileHelpers.cleanup(dir) }

        let target = dir.appendingPathComponent("target")
        let link = dir.appendingPathComponent("link")
        try "x".write(to: target, atomically: true, encoding: .utf8)
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: target)

        #expect(CanonicalPath.make(for: link.path) == CanonicalPath.make(for: target.path))
        #expect(CanonicalPath.make(for: link.path).hasSuffix("/target"))
    }
}
