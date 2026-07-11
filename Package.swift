// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "swift-cbor",
  platforms: [.macOS(.v11), .iOS(.v14)],
  products: [
    .library(
      name: "SwiftCbor",
      targets: ["SwiftCbor"])
  ],
  targets: [
    .target(name: "SwiftCbor"),
    .executableTarget(
      name: "example",
      dependencies: [
        "SwiftCbor"
      ],
      path: "Example"
    ),
    .testTarget(
      name: "SwiftCborTests",
      dependencies: ["SwiftCbor"]
    ),
  ]
)
