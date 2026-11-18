// Licensed under GPL-3.0. See LICENSE.
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "VegaWeb",
    platforms: [.macOS("15.5"), .iOS("26.0")],
    products: [
        .library(name: "VegaWeb", targets: ["VegaWeb"]),
    ],
    dependencies: [
        .package(path: "../VegaTabsCore"),
        .package(path: "../VegaSettings"),
        .package(path: "../VegaBlocker"),
        .package(path: "../VegaTweaks"),
        .package(url: "https://github.com/will-lumley/FaviconFinder.git", from: "5.1.5"),
        // FaviconFinder's own HTML parser: Vega fetches the page itself (as Safari) and hands it the parsed page.
        .package(url: "https://github.com/scinfu/SwiftSoup.git", from: "2.3.7"),
    ],
    targets: [
        .target(name: "MuteableWKWebView", path: "Sources/MuteableWKWebView", publicHeadersPath: "include"),
        .target(
            name: "VegaWeb",
            dependencies: [
                // Page muting reaches a private WebKit call through NSTask and nm; macOS only.
                .target(name: "MuteableWKWebView", condition: .when(platforms: [.macOS])),
                .product(name: "VegaTabsCore", package: "VegaTabsCore"),
                .product(name: "VegaSettings", package: "VegaSettings"),
                .product(name: "VegaBlocker", package: "VegaBlocker"),
                .product(name: "VegaTweaks", package: "VegaTweaks"),
                .product(name: "FaviconFinder", package: "FaviconFinder"),
                .product(name: "SwiftSoup", package: "SwiftSoup"),
            ],
            resources: [.copy("Resources")],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]
)
