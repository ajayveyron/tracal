// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "TracalCore",
    platforms: [
        .iOS(.v16),
        .macOS(.v13),
    ],
    products: [
        .library(name: "TracalCore", targets: ["TracalCore"]),
    ],
    targets: [
        .target(name: "TracalCore"),
        .testTarget(name: "TracalCoreTests", dependencies: ["TracalCore"]),
    ]
)
