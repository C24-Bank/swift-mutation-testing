enum MutantID {
    static let prefix = "swift-mutation-testing_"

    static func make(index: Int) -> String {
        "\(prefix)\(index)"
    }

    static func index(of id: String) -> Int? {
        guard id.hasPrefix(prefix) else { return nil }
        return Int(id.dropFirst(prefix.count))
    }

    static func ordered<Item>(_ items: [Item], by id: (Item) -> String) -> [Item] {
        items.map { (position: index(of: id($0)) ?? 0, item: $0) }
            .sorted { $0.position < $1.position }
            .map(\.item)
    }
}
