// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Iron",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "Iron",
            targets: ["Iron"]
        ),
        .executable(
            name: "IronApp",
            targets: ["IronApp"]
        ),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "Iron",
            resources: [
                .process("UI/Metal/Shaders.metal")
            ]
        ),
        .executableTarget(
            name: "IronApp",
            dependencies: ["Iron"],
            linkerSettings: [
                .linkedFramework("SwiftUI"),
                .linkedFramework("Metal"),
                .linkedFramework("MetalKit"),
                .linkedFramework("AppKit"),
            ]
        ),
        .testTarget(
            name: "IronTests",
            dependencies: ["Iron"]
        ),
    ]
)
