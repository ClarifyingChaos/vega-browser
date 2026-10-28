// Licensed under GPL-3.0. See LICENSE.
//
//  EmptyWebsiteView.swift
//  Vega
//
//  Created by Maciek Bagiński on 28/07/2025.
//

import SwiftUI
import VegaDesign
import VegaWeb

public struct EmptyWebsiteView: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(BrowserWindowState.self) private var windowState
    @Environment(WindowRegistry.self) var windowRegistry
    @Environment(TabsController.self) private var tabs
    @Environment(\.tabActions) private var actions

    public init() {}

    public var body: some View {
        GeometryReader { proxy in
            ZStack {
                // Match the container background so this reads as chrome, not webview content.
                let accent = windowState.isIncognito ? VegaDesign.Surface.incognitoAccent : (actions?.accentColor ?? .accentColor)
                let isActive = windowRegistry.activeWindowId == windowState.id

                let theme = windowState.isIncognito ? nil : windowState.spaceDraftTheme ?? windowState.spaceID.flatMap { tabs.space($0)?.theme }
                SpaceChromeBackground(theme: theme, accent: accent, isActive: isActive)
                    .clipShape(VegaDesign.Radius.shape(VegaDesign.Radius.lg))
                    .vegaElevation(.raised)
                    .animation(VegaDesign.Motion.standard, value: isActive)

                VStack(spacing: 16) {
                    Image(systemName: "moon.stars")
                        .font(VegaDesign.Font.display)
                        .blendMode(.overlay)

                    Text("Ah, peace.")
                        .font(VegaDesign.Font.title)
                        .foregroundColor(colorScheme == .dark ? .white.opacity(0.7) : .black.opacity(0.6))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
