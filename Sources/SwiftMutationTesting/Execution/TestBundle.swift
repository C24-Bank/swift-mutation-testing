import Foundation

struct TestBundle: Sendable, Equatable {
    static let allLibraries: Set<TestingFramework> = [.xctest, .swiftTesting]

    let url: URL
    var libraries: Set<TestingFramework>

    var name: String {
        url.deletingPathExtension().lastPathComponent
    }

    static func all(in sandbox: Sandbox) -> [TestBundle] {
        TestBundleInvocation.bundleURLs(in: sandbox).map { TestBundle(url: $0, libraries: allLibraries) }
    }
}
