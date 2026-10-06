public struct Greeter {
    public init() {}

    public func greeting(for name: String) -> String {
        name.isEmpty ? "Hello" : "Hello, " + name
    }

    public func isShort(_ name: String) -> Bool {
        name.count < 4
    }
}
