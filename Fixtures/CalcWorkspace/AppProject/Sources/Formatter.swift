public struct Formatter {
    public init() {}

    public func shout(_ text: String, loud: Bool) -> String {
        loud && !text.isEmpty ? text.uppercased() : text
    }
}
