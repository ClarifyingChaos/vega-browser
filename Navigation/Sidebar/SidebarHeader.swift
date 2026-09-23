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

/// Header section of the sidebar (window controls and space name, URL bar). Back, forward and
/// reload sit in the title row above it.
struct SidebarHeader: View {
    @EnvironmentObject var browserManager: BrowserManager
    @Environment(BrowserWindowState.self) private var windowState
    @Environment(\.vegaSettings) var vegaSettings
    let isSidebarHovered: Bool
    let onNewSpace: () -> Void

    var body: some View {
        VStack(spacing: VegaDesign.Spacing.sectionGap) {
            windowControls

            if !vegaSettings.topBarAddressView {
                urlBar
            }
        }
    }

    private var windowControls: some View {
        SidebarWindowControlsView(onNewSpace: onNewSpace)
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
/// The sidebar and AI toggles, with the space name at the trailing edge.
struct SidebarWindowControlsView: View {
    @EnvironmentObject var browserManager: BrowserManager
    @Environment(BrowserWindowState.self) private var windowState
    @Environment(\.vegaSettings) var vegaSettings
    let onNewSpace: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            // One glass pill, the way the system groups neighbouring toolbar buttons.
            HStack(spacing: 0) {
                Button("Toggle Sidebar", systemImage: vegaSettings.sidebarPosition == .left ? "sidebar.left" : "sidebar.right") {
                    browserManager.toggleSidebar(for: windowState)
                }

                if vegaSettings.showAIAssistant {
                    Button("Toggle AI Assistant", systemImage: "sparkle") {
                        browserManager.toggleAISidebar(for: windowState)
                    }
                }
            }
            .vegaGlassControls(in: Capsule())

            Spacer(minLength: 0)

            // Gives way before the pill: a long name fades out.
            SpaceSwitcherTitle(onNewSpace: onNewSpace)
                .layoutPriority(1)
        }
        .frame(height: VegaDesign.Size.glassControl)
        .background(DoubleClickView { NSApp.keyWindow?.performZoom(nil) })
    }
}
