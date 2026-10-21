import Foundation

struct XCTestRunPlist: Sendable, Equatable {
    typealias PlistSerializer = ([String: Any]) throws -> Data

    init?(_ data: Data) {
        guard (try? PropertyListSerialization.propertyList(from: data, options: [], format: nil)) is [String: Any]
        else { return nil }
        self.data = data
    }

    private let data: Data

    /// Test target names keyed by their module name, e.g. `C24_MockedTests` → `C24 MockedTests`.
    var testTargetsByModule: [String: String] {
        guard
            let dict = (try? PropertyListSerialization.propertyList(from: data, options: [], format: nil))
                as? [String: Any]
        else { return [:] }

        let targets: [[String: Any]]
        if let configurations = dict["TestConfigurations"] as? [[String: Any]] {
            targets = configurations.flatMap { $0["TestTargets"] as? [[String: Any]] ?? [] }
        } else {
            targets = dict.filter { !$0.key.hasPrefix("__") }.compactMap { $0.value as? [String: Any] }
        }

        var result: [String: String] = [:]
        for target in targets {
            guard let name = target["BlueprintName"] as? String else { continue }
            let module = target["ProductModuleName"] as? String ?? name
            result[module] = name
        }
        return result
    }

    func activating(
        _ mutantID: String,
        serialize: PlistSerializer = {
            try PropertyListSerialization.data(fromPropertyList: $0, format: .xml, options: 0)
        }
    ) -> Data {
        guard
            var dict = (try? PropertyListSerialization.propertyList(from: data, options: [], format: nil))
                as? [String: Any]
        else { return data }

        if var configurations = dict["TestConfigurations"] as? [[String: Any]] {
            for index in configurations.indices {
                if var targets = configurations[index]["TestTargets"] as? [[String: Any]] {
                    for targetIndex in targets.indices {
                        var envVars = targets[targetIndex]["EnvironmentVariables"] as? [String: String] ?? [:]
                        envVars["__SWIFT_MUTATION_TESTING_ACTIVE"] = mutantID
                        targets[targetIndex]["EnvironmentVariables"] = envVars
                        targets[targetIndex].removeValue(forKey: "TestRepetitionPolicy")
                    }
                    configurations[index]["TestTargets"] = targets
                }
            }
            dict["TestConfigurations"] = configurations
        } else {
            for key in dict.keys where !key.hasPrefix("__") {
                if var targetDict = dict[key] as? [String: Any] {
                    var envVars = targetDict["EnvironmentVariables"] as? [String: String] ?? [:]
                    envVars["__SWIFT_MUTATION_TESTING_ACTIVE"] = mutantID
                    targetDict["EnvironmentVariables"] = envVars
                    targetDict.removeValue(forKey: "TestRepetitionPolicy")
                    dict[key] = targetDict
                }
            }
        }

        return (try? serialize(dict)) ?? data
    }
}
