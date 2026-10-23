// Licensed under GPL-3.0. See LICENSE.
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "VegaSettings",
    platforms: [.macOS("15.5"), .iOS("26.0")],
    products: [
        .library(name: "VegaSettings", targets: ["VegaSettings"]),
    ],
    targets: [
        .target(name: "VegaSettings", swiftSettings: [.swiftLanguageMode(.v5)]),
    ]
)
