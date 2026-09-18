// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "VegaWeb",
    platforms: [.macOS("26.0"), .iOS("26.0")],
    products: [
        .library(name: "VegaWeb", targets: ["VegaWeb"]),
    ],
    dependencies: [
        .package(path: "../VegaTabsCore"),
        .package(path: "../VegaSettings"),
        .package(path: "../VegaBlocker"),
        .package(path: "../VegaTweaks"),
        .package(url: "https://github.com/will-lumley/FaviconFinder.git", from: "5.1.5"),
    ],
    targets: [
        .target(name: "MuteableWKWebView", path: "Sources/MuteableWKWebView", publicHeadersPath: "include"),
        .target(
            name: "VegaWeb",
            dependencies: [
                "MuteableWKWebView",
                .product(name: "VegaTabsCore", package: "VegaTabsCore"),
                .product(name: "VegaSettings", package: "VegaSettings"),
                .product(name: "VegaBlocker", package: "VegaBlocker"),
                .product(name: "VegaTweaks", package: "VegaTweaks"),
                .product(name: "FaviconFinder", package: "FaviconFinder"),
            ],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]
)
