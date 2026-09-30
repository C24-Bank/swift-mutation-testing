// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CalcModules",
    targets: [
        .target(name: "CoreA"),
        .target(name: "CoreB"),
        .testTarget(name: "CoreATests", dependencies: ["CoreA"]),
        .testTarget(name: "CoreBTests", dependencies: ["CoreB"]),
    ]
)
