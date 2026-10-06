import Foundation
import SwiftIfConfig
import SwiftSyntax

struct HostBuildConfiguration: BuildConfiguration {
    enum ImportError: Error {
        case undecidable(module: String)
    }

    static let modulesPresent: Set<String> = [
        "Swift", "_Concurrency", "Darwin", "Foundation", "CoreFoundation", "Dispatch", "ObjectiveC", "os", "OSLog",
        "Combine", "Observation", "Synchronization", "System", "Security", "Network", "CryptoKit", "Accelerate",
        "CoreGraphics", "AppKit", "SwiftUI", "Metal", "XCTest", "Testing",
    ]

    static let modulesAbsent: Set<String> = [
        "Glibc", "Musl", "Bionic", "Android", "WinSDK", "CRT", "ucrt", "WASILibc", "UIKit", "WatchKit", "TVUIKit",
    ]

    private let base: StaticBuildConfiguration

    init(compilerVersion: VersionTuple = Self.hostCompilerVersion) {
        base = StaticBuildConfiguration(
            customConditions: ["DEBUG", "SWIFT_PACKAGE"],
            targetOSs: ["macOS", "OSX"],
            targetArchitectures: [Self.hostArchitecture],
            targetRuntimes: ["_ObjC", "_multithreaded"],
            targetObjectFileFormats: ["MachO"],
            targetPointerBitWidth: 64,
            targetAtomicBitWidths: [8, 16, 32, 64, 128],
            languageVersion: VersionTuple(6),
            compilerVersion: compilerVersion
        )
    }

    static var hostArchitecture: String {
        #if arch(arm64)
            return "arm64"
        #else
            return "x86_64"
        #endif
    }

    static let hostCompilerVersion: VersionTuple = {
        #if compiler(>=6.4)
            VersionTuple(6, 4)
        #elseif compiler(>=6.3)
            VersionTuple(6, 3)
        #elseif compiler(>=6.2)
            VersionTuple(6, 2)
        #else
            VersionTuple(6, 1)
        #endif
    }()

    func isCustomConditionSet(name: String) throws -> Bool { try base.isCustomConditionSet(name: name) }
    func hasFeature(name: String) throws -> Bool { try base.hasFeature(name: name) }
    func hasAttribute(name: String) throws -> Bool { try base.hasAttribute(name: name) }
    func isActiveTargetOS(name: String) throws -> Bool { try base.isActiveTargetOS(name: name) }
    func isActiveTargetArchitecture(name: String) throws -> Bool { try base.isActiveTargetArchitecture(name: name) }
    func isActiveTargetEnvironment(name: String) throws -> Bool { try base.isActiveTargetEnvironment(name: name) }
    func isActiveTargetRuntime(name: String) throws -> Bool { try base.isActiveTargetRuntime(name: name) }
    func isActiveTargetPointerAuthentication(name: String) throws -> Bool {
        try base.isActiveTargetPointerAuthentication(name: name)
    }
    func isActiveTargetObjectFormat(name: String) throws -> Bool { try base.isActiveTargetObjectFormat(name: name) }
    var targetPointerBitWidth: Int { base.targetPointerBitWidth }
    var targetAtomicBitWidths: [Int] { base.targetAtomicBitWidths }
    var endianness: Endianness { base.endianness }
    var languageVersion: VersionTuple { base.languageVersion }
    var compilerVersion: VersionTuple { base.compilerVersion }

    func canImport(importPath: [(TokenSyntax, String)], version _: CanImportVersion) throws -> Bool {
        let module = importPath.first?.1 ?? ""
        if Self.modulesPresent.contains(module) { return true }
        if Self.modulesAbsent.contains(module) { return false }
        throw ImportError.undecidable(module: module)
    }
}
