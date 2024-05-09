// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "swift-cbor",
    platforms: [.macOS(.v10_13), .iOS(.v14)],
    products: [
        .library(
            name: "SwiftCbor",
            targets: ["SwiftCbor"]),
    ],
    dependencies: [
        .package(url: "https://github.com/nicklockwood/SwiftFormat", exact: "0.53.8")
    ],
    targets: [
        .target(name: "SwiftCbor"),
        .executableTarget(
            name: "example",
            dependencies: [
                "SwiftCbor",
            ],
            path: "Example"
        ),
        .testTarget(
            name: "SwiftCborTests",
            dependencies: ["SwiftCbor"]
        ),
    ]
)
