// Licensed under GPL-3.0. See LICENSE.
//
//  SidebarHeader.swift
//  Vega
//
//  Created by Aether on 15/11/2025.
//

import SwiftUI
import VegaDesign
import VegaWeb
import VegaUI

/// Header section of the sidebar (window controls, URL bar). Back, forward and reload sit in the
/// title row above it.
struct SidebarHeader: View {
    @EnvironmentObject var browserManager: BrowserManager
    @Environment(BrowserWindowState.self) private var windowState
    @Environment(\.vegaSettings) var vegaSettings
    let isSidebarHovered: Bool

    var body: some View {
        VStack(spacing: VegaDesign.Spacing.sectionGap) {
            windowControls

            if !vegaSettings.topBarAddressView {
                urlBar
            }
        }
    }

    private var windowControls: some View {
        SidebarWindowControlsView()
            .environmentObject(browserManager)
            .environment(windowState)
            .padding(.horizontal, VegaDesign.Spacing.sidebarInset)
    }

    private var urlBar: some View {
        URLBarView(isSidebarHovered: isSidebarHovered)
            .padding(.horizontal, VegaDesign.Spacing.sidebarInset)
    }
}

// MARK: - Sidebar Window Controls
struct SidebarWindowControlsView: View {
    @EnvironmentObject var browserManager: BrowserManager
    @Environment(BrowserWindowState.self) private var windowState
    @Environment(\.vegaSettings) var vegaSettings

    var body: some View {
        HStack(spacing: VegaDesign.Spacing.md) {
            Button("Toggle Sidebar", systemImage: vegaSettings.sidebarPosition == .left ? "sidebar.left" : "sidebar.right") {
                browserManager.toggleSidebar(for: windowState)
            }
            .labelStyle(.iconOnly)
            .buttonStyle(VegaIconButtonStyle())
            .foregroundStyle(Color.primary)

            if vegaSettings.showAIAssistant {
                Button("Toggle AI Assistant", systemImage: "sparkle") {
                    browserManager.toggleAISidebar(for: windowState)
                }
                .labelStyle(.iconOnly)
                .buttonStyle(VegaIconButtonStyle())
                .foregroundStyle(Color.primary)
            }

            Spacer()
        }
        .frame(height: VegaDesign.Size.navRow)
        .background(DoubleClickView { NSApp.keyWindow?.performZoom(nil) })
    }
}
