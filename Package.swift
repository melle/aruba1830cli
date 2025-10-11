// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Aruba1830CLI",
    platforms: [
        .macOS(.v13),
    ],
    products: [
        .library(
            name: "Aruba1830CLICore",
            targets: ["Aruba1830CLICore"]
        ),
        .executable(
            name: "aruba1830",
            targets: ["Aruba1830CLI"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.3.0"),
    ],
    targets: [
        // Library target containing core functionality
        .target(
            name: "Aruba1830CLICore",
            dependencies: [],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
            ]
        ),
        
        // Executable target that uses the library
        .executableTarget(
            name: "Aruba1830CLI",
            dependencies: [
                "Aruba1830CLICore",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
            ]
        ),
        
        // Tests for the library
        .testTarget(
            name: "Aruba1830CLICoreTests",
            dependencies: ["Aruba1830CLICore"],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
            ]
        ),
    ]
)
