public struct Bounds {
    public init() {}

    public func contains(_ value: Int, from low: Int, to high: Int) -> Bool {
        value >= low && value <= high
    }
}
