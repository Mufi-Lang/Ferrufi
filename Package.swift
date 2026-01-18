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
        .package(url: "https://github.com/JohnSundell/Files.git", from: "4.0.0"),
        .package(url: "https://github.com/kylef/PathKit.git", from: "1.0.0"),
    ],
    targets: [
        .systemLibrary(
            name: "CMufi",
            path: "Sources/CMufi"
        ),
        .target(
            name: "Ferrufi",
            dependencies: [
                "CMufi",
                .product(name: "Files", package: "Files"),
                .product(name: "PathKit", package: "PathKit"),
            ],
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
