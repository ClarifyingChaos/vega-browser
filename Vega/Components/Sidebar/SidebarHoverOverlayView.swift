// Licensed under GPL-3.0. See LICENSE.
//
//  SidebarHoverOverlayView.swift
//  Vega
//
//  Created by Jonathan Caudill on 2025-09-13.
//

import SwiftUI
import AppKit
import VegaDesign
import VegaTabsCore
import VegaWeb
import VegaUI

struct SidebarHoverOverlayView: View {
    @EnvironmentObject var browserManager: BrowserManager
    @EnvironmentObject var hoverManager: HoverSidebarManager
    @Environment(BrowserWindowState.self) private var windowState
    @Environment(CommandPalette.self) private var commandPalette
    @Environment(\.vegaSettings) var vegaSettings

    private let cornerRadius: CGFloat = VegaDesign.Radius.lg
    private let horizontalInset: CGFloat = VegaDesign.Spacing.md
    private let verticalInset: CGFloat = VegaDesign.Spacing.md

    var body: some View {
        // Only render overlay plumbing when the real sidebar is collapsed
        if !windowState.isSidebarVisible {
            ZStack(alignment: vegaSettings.sidebarPosition == .left ? .leading : .trailing) {
                // Edge hover hotspot
                Color.clear
                    .frame(width: hoverManager.triggerWidth)
                    .contentShape(Rectangle())
                    .onHoverTracking { isIn in
                        if isIn && !windowState.isSidebarVisible {
                            withAnimation(VegaDesign.Motion.quick) {
                                hoverManager.isOverlayVisible = true
                            }
                        }
                        NSCursor.arrow.set()
                    }

                if hoverManager.isOverlayVisible {
                    SpacesSideBarView()
                        .spaceThemeAppearance(overlayTheme)
                        .frame(width: windowState.sidebarWidth)
                        .environmentObject(browserManager)
                        .environment(windowState)
                        .environment(commandPalette)
                        .environmentObject(browserManager.gradientColorManager)
                        .frame(maxHeight: .infinity)
                        // Clip the floating surface, not descendants: the expanded address
                        // panel is anchored here but deliberately extends over the page.
                        // FORK: the floating sidebar sits over the page, so it is Liquid Glass tinted with
                        // the space's color (HIG, Sidebars), not an opaque card.
                        .vegaGlassSurface(in: VegaDesign.Radius.shape(cornerRadius), tint: overlayTint)
                        .alwaysArrowCursor()
                        .padding(vegaSettings.sidebarPosition == .left ? .leading : .trailing, horizontalInset)
                        .padding(.vertical, verticalInset)
                        .transition(
                            .move(edge: vegaSettings.sidebarPosition == .left ? .leading : .trailing)
                                .combined(with: .opacity)
                        )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: vegaSettings.sidebarPosition == .left ? .topLeading : .topTrailing)
            // Container remains passive; only overlay/hotspot intercept
        }
    }

    private var overlayTheme: SpaceTheme? {
        guard !windowState.isIncognito, let spaceID = windowState.spaceID, spaceID != browserManager.tabs.agentSpaceID else { return nil }
        return browserManager.tabs.space(spaceID)?.theme
    }

    private var overlayTint: Color {
        (windowState.isIncognito ? SpaceGradient.incognito.primaryColor : browserManager.gradientColorManager.accentColor).opacity(0.35)
    }
}
