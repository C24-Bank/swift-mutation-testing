import Foundation

@testable import SwiftMutationTesting

extension ProcessRequest {
    func recordActivation() {
        guard let path = activationFilePath else { return }
        FileManager.default.createFile(atPath: path, contents: nil)
    }

    private var activationFilePath: String? {
        if let path = additionalEnvironment[ActivationMarker.environmentVariable] { return path }

        guard
            let index = arguments.firstIndex(of: "-xctestrun"), index + 1 < arguments.count,
            let data = FileManager.default.contents(atPath: arguments[index + 1]),
            let plist = try? PropertyListSerialization.propertyList(from: data, format: nil)
        else { return nil }

        return Self.activationFilePath(in: plist)
    }

    private static func activationFilePath(in plist: Any) -> String? {
        if let dictionary = plist as? [String: Any] {
            if let path = dictionary[ActivationMarker.environmentVariable] as? String { return path }
            return dictionary.values.lazy.compactMap(activationFilePath(in:)).first
        }
        if let array = plist as? [Any] {
            return array.lazy.compactMap(activationFilePath(in:)).first
        }
        return nil
    }
}
