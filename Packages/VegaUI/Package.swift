// Licensed under GPL-3.0 with the App Store exception in LICENSE-EXCEPTION.md.
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "VegaUI",
    platforms: [.macOS("26.0"), .iOS("26.0")],
    products: [
        .library(name: "VegaUI", targets: ["VegaUI"]),
    ],
    dependencies: [
        .package(path: "../VegaBlocker"),
        .package(path: "../VegaDesign"),
        .package(path: "../VegaSettings"),
        .package(path: "../VegaTabsCore"),
        .package(path: "../VegaTweaks"),
        .package(path: "../VegaWeb"),
    ],
    targets: [
        .target(
            name: "VegaUI",
            dependencies: [
                .product(name: "VegaBlocker", package: "VegaBlocker"),
                .product(name: "VegaDesign", package: "VegaDesign"),
                .product(name: "VegaSettings", package: "VegaSettings"),
                .product(name: "VegaTabsCore", package: "VegaTabsCore"),
                .product(name: "VegaTweaks", package: "VegaTweaks"),
                .product(name: "VegaWeb", package: "VegaWeb"),
            ],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]
)
