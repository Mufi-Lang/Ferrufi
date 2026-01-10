// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Ferrufi",
    platforms: [
        .macOS(.v26)
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
            ],
            linkerSettings: [
                .unsafeFlags(["-L", "Sources/CMufi"]),
                .linkedLibrary("mufiz"),
            ]
        ),
        .executableTarget(
            name: "FerrufiApp",
            dependencies: ["Ferrufi"],
            linkerSettings: [
                .unsafeFlags(["-L", "Sources/CMufi"]),
                .unsafeFlags([
                    "-Xlinker", "-rpath", "-Xlinker", "@loader_path/../../../Sources/CMufi",
                    "-Xlinker", "-rpath", "-Xlinker", "@executable_path/../../../Sources/CMufi",
                ]),
                .linkedLibrary("mufiz"),
            ]
        ),

        .testTarget(
            name: "FerrufiTests",
            dependencies: ["Ferrufi"],
            linkerSettings: [
                .unsafeFlags(["-L", "Sources/CMufi"]),
                .unsafeFlags([
                    "-Xlinker", "-rpath", "-Xlinker", "@loader_path/../../../Sources/CMufi",
                    "-Xlinker", "-rpath", "-Xlinker", "@executable_path/../../../Sources/CMufi",
                ]),
                .linkedLibrary("mufiz"),
            ]
        ),
    ]
)
