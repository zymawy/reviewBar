// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "ReviewBar",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "ReviewBar", targets: ["ReviewBar"]),
        .executable(name: "reviewbar", targets: ["ReviewBarCLI"]),
        .library(name: "ReviewBarCore", targets: ["ReviewBarCore"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.3.0"),
        .package(url: "https://github.com/kishikawakatsumi/KeychainAccess.git", from: "4.2.2"),
        .package(url: "https://github.com/sparkle-project/Sparkle.git", from: "2.6.0"),
        .package(url: "https://github.com/jpsim/Yams.git", from: "5.0.0"),
    ],
    targets: [
        // MARK: - Core Library (no UI dependencies)
        .target(
            name: "ReviewBarCore",
            dependencies: [
                .product(name: "KeychainAccess", package: "KeychainAccess"),
                .product(name: "Yams", package: "Yams"),
            ],
            path: "Sources/ReviewBarCore",
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
        
        // MARK: - macOS App
        .executableTarget(
            name: "ReviewBar",
            dependencies: [
                "ReviewBarCore",
                .product(name: "Sparkle", package: "Sparkle"),
            ],
            path: "Sources/ReviewBar",
            resources: [
                .process("Resources")
            ],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
        
        // MARK: - CLI Tool
        .executableTarget(
            name: "ReviewBarCLI",
            dependencies: [
                "ReviewBarCore",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ],
            path: "Sources/ReviewBarCLI",
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
        
        // MARK: - Tests
        .testTarget(
            name: "ReviewBarCoreTests",
            dependencies: ["ReviewBarCore"],
            path: "Tests/ReviewBarCoreTests"
        ),
        .testTarget(
            name: "ReviewBarTests",
            dependencies: ["ReviewBar"],
            path: "Tests/ReviewBarTests"
        ),
    ]
)
