// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "LocalDictate",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .library(name: "LocalDictateCore", targets: ["LocalDictateCore"]),
        .executable(name: "LocalDictate", targets: ["LocalDictate"]),
        .executable(name: "localdictate", targets: ["LocalDictateCLI"])
    ],
    targets: [
        .target(
            name: "LocalDictateCore"
        ),
        .executableTarget(
            name: "LocalDictate",
            dependencies: ["LocalDictateCore"],
            resources: [
                .process("Resources")
            ]
        ),
        .executableTarget(
            name: "LocalDictateCLI",
            dependencies: ["LocalDictateCore"]
        ),
        .testTarget(
            name: "LocalDictateCoreTests",
            dependencies: ["LocalDictateCore"]
        )
    ]
)
