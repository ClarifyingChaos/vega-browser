// Licensed under GPL-3.0 with the App Store exception in LICENSE-EXCEPTION.md.
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "VegaBlocker",
    platforms: [.macOS("26.0"), .iOS("26.0")],
    products: [
        .library(name: "VegaBlocker", targets: ["VegaBlocker"]),
    ],
    dependencies: [
        .package(path: "../VegaSettings"),
    ],
    targets: [
        .binaryTarget(
            name: "VegaAdblockFFI",
            path: "../../Vega/ThirdParty/AdblockRustFFI/VegaAdblock.xcframework"
        ),
        .target(
            name: "VegaBlocker",
            dependencies: [
                "VegaAdblockFFI",
                .product(name: "VegaSettings", package: "VegaSettings"),
            ],
            resources: [.copy("Resources")],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]
)
