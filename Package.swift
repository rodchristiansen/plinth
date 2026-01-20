// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Plinth",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .executable(name: "Plinth", targets: ["Plinth"])
    ],
    targets: [
        .executableTarget(
            name: "Plinth",
            exclude: [
                "Resources/Info.plist",
                "Resources/Plinth.entitlements"
            ],
            resources: [
                .process("Resources/Assets.xcassets"),
                .copy("Resources/LaunchAgents")
            ],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
        .testTarget(
            name: "PlinthTests",
            dependencies: ["Plinth"]
        )
    ]
)
