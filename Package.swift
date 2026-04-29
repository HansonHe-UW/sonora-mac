// swift-tools-version: 6.0

import PackageDescription

let package = Package(
  name: "Sonora",
  platforms: [
    .macOS(.v14)
  ],
  products: [
    .executable(name: "Sonora", targets: ["Sonora"])
  ],
  targets: [
    .executableTarget(
      name: "Sonora"
    ),
    .testTarget(
      name: "SonoraTests",
      dependencies: ["Sonora"]
    )
  ]
)
