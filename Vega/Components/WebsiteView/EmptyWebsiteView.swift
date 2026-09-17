//
//  EmptyWebsiteView.swift
//  Vega
//
//  Created by Maciek Bagiński on 28/07/2025.
//

import SwiftUI
import VegaDesign

struct EmptyWebsiteView: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var browserManager: BrowserManager
    @Environment(BrowserWindowState.self) private var windowState
    @Environment(WindowRegistry.self) var windowRegistry

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                // Match the container background so this reads as chrome, not webview content.
                let accent = windowState.isIncognito ? SpaceGradient.incognito.primaryColor : browserManager.gradientColorManager.accentColor
                let isActive = windowRegistry.activeWindowId == windowState.id

                VegaDesign.Surface.containerGradient(accent: accent, isActive: isActive)
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
