// Licensed under GPL-3.0 with the App Store exception in LICENSE-EXCEPTION.md.
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "VegaTweaks",
    platforms: [.macOS("26.0"), .iOS("26.0")],
    products: [
        .library(name: "VegaTweaks", targets: ["VegaTweaks"]),
    ],
    dependencies: [
        .package(path: "../VegaSettings"),
        .package(path: "../VegaBlocker"),
    ],
    targets: [
        .target(
            name: "VegaTweaks",
            dependencies: [
                .product(name: "VegaSettings", package: "VegaSettings"),
                .product(name: "VegaBlocker", package: "VegaBlocker"),
            ],
            resources: [.copy("Resources")],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]
)
