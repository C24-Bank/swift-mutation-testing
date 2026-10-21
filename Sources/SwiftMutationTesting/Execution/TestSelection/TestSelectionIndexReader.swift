import Foundation
import SwiftIndexStore

/// Reads the build's index store into the facts a `TestSelection` is computed from.
struct TestSelectionIndexReader: Sendable {
    let storeURL: URL
    let libraryURL: URL

    /// - Parameters:
    ///   - sourceFiles: The mutated files whose definitions are looked up.
    ///   - testTargetsByModule: Test module names mapped to the target names `-only-testing` expects.
    func read(sourceFiles: Set<String>, testTargetsByModule: [String: String]) throws -> TestSelectionFacts {
        let library = try LibIndexStore.open(url: libraryURL)
        let store = try IndexStore.open(store: storeURL, lib: library)
        let wanted = Set(sourceFiles.map(TestSelection.normalized))
        var facts = TestSelectionFacts()

        for unit in store.units(includeSystem: false) {
            guard
                let mainFile = try store.mainFilePath(for: unit),
                let module = try store.moduleName(for: unit)
            else { continue }

            let path = TestSelection.normalized(mainFile)

            if let target = testTargetsByModule[module] {
                guard FileManager.default.fileExists(atPath: path) else { continue }
                var file = facts.testFiles[path] ?? TestFileFacts(target: target)
                try readTestFile(unit: unit, mainFile: mainFile, in: store, into: &file, facts: &facts)
                facts.testFiles[path] = file
            } else if wanted.contains(path) {
                facts.definitions[path, default: []].formUnion(
                    try definitions(unit: unit, mainFile: mainFile, in: store)
                )
            }
        }

        for path in wanted where facts.definitions[path] == nil {
            facts.definitions[path] = []
        }

        return facts
    }

    private func records(of unit: IndexStoreUnit, mainFile: String, in store: IndexStore) throws
        -> [IndexStoreUnit.Dependency.Record]
    {
        try store.recordDependencies(for: unit).compactMap { dependency in
            guard let record = dependency.record, record.filePath == mainFile else { return nil }
            return record
        }
    }

    private func definitions(unit: IndexStoreUnit, mainFile: String, in store: IndexStore) throws -> Set<String> {
        var usrs: Set<String> = []
        for record in try records(of: unit, mainFile: mainFile, in: store) {
            try store.forEachOccurrences(for: record) { occurrence in
                if occurrence.roles.contains(.definition), occurrence.symbol.kind != .parameter,
                    let usr = occurrence.symbol.usr
                {
                    usrs.insert(usr)
                }
                return true
            }
        }
        return usrs
    }

    private func readTestFile(
        unit: IndexStoreUnit,
        mainFile: String,
        in store: IndexStore,
        into file: inout TestFileFacts,
        facts: inout TestSelectionFacts
    ) throws {
        var types: [TestFileType] = []
        var testRecordUSRs: [String] = []
        var references = file.references
        var subclassesByBase = facts.subclassesByBase

        for record in try records(of: unit, mainFile: mainFile, in: store) {
            try store.forEachOccurrences(for: record) { occurrence in
                guard let usr = occurrence.symbol.usr else { return true }
                var isNested = false

                store.forEachRelations(for: occurrence) { relation in
                    if relation.roles.contains(.childOf) {
                        isNested = true
                    }
                    if relation.roles.contains(.baseOf), let subclass = relation.symbol.usr {
                        subclassesByBase[usr, default: []].insert(subclass)
                    }
                    return true
                }

                if occurrence.roles.contains(.reference) {
                    references.insert(usr)
                }

                guard occurrence.roles.contains(.definition) else { return true }

                if occurrence.symbol.name?.contains("testContentRecord") == true {
                    testRecordUSRs.append(usr)
                }

                if !isNested, [.class, .struct, .enum].contains(occurrence.symbol.kind),
                    let name = occurrence.symbol.name
                {
                    types.append(TestFileType(usr: usr, name: name, isSwiftTestingSuite: false))
                }
                return true
            }
        }

        for index in types.indices {
            let prefix = types[index].usr
            types[index].isSwiftTestingSuite = testRecordUSRs.contains { $0.hasPrefix(prefix) }
        }

        file.references = references
        for type in types where !file.types.contains(where: { $0.usr == type.usr }) {
            file.types.append(type)
        }
        facts.subclassesByBase = subclassesByBase
    }
}
