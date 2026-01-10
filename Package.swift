// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Ferrufi",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "Ferrufi",
            targets: ["Ferrufi"]
        ),
        .executable(
            name: "FerrufiApp",
            targets: ["FerrufiApp"]
        ),
    ],
    dependencies: [
        // No external dependencies - using only system frameworks
    ],
    targets: [
        .systemLibrary(
            name: "CMufi",
            path: "Sources/CMufi"
        ),
        .target(
            name: "Ferrufi",
            dependencies: ["CMufi"],
            resources: [
                .process("UI/Metal/Shaders.metal")
            ]
        ),
        .executableTarget(
            name: "FerrufiApp",
            dependencies: ["Ferrufi"],
        ),

        .testTarget(
            name: "FerrufiTests",
            dependencies: ["Ferrufi"]
        ),
    ]
)
