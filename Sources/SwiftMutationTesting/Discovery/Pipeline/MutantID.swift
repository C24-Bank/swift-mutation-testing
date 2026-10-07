/// The id a mutant carries in reports, schemata and the environment that activates it: its position in the
/// run's ordered list of mutants, behind a fixed prefix.
enum MutantID {
    static let prefix = "swift-mutation-testing_"

    static func make(index: Int) -> String {
        "\(prefix)\(index)"
    }

    /// The position `id` names, or `nil` for a string that is not a mutant id.
    static func index(of id: String) -> Int? {
        guard id.hasPrefix(prefix) else { return nil }
        return Int(id.dropFirst(prefix.count))
    }

    /// `items` in the order of their mutants' positions, each id read once; an id that names no position
    /// sorts as the first one.
    static func ordered<Item>(_ items: [Item], by id: (Item) -> String) -> [Item] {
        items.map { (position: index(of: id($0)) ?? 0, item: $0) }
            .sorted { $0.position < $1.position }
            .map(\.item)
    }
}
