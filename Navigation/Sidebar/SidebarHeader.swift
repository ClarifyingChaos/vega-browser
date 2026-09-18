// Licensed under GPL-3.0 with the App Store exception in LICENSE-EXCEPTION.md.
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

/// Header section of the sidebar (window controls, navigation buttons, URL bar)
struct SidebarHeader: View {
    @EnvironmentObject var browserManager: BrowserManager
    @Environment(BrowserWindowState.self) private var windowState
    @Environment(\.vegaSettings) var vegaSettings
    let isSidebarHovered: Bool
    @State private var sidebarWidth: CGFloat = 0

    var body: some View {
        VStack(spacing: VegaDesign.Spacing.sectionGap) {
            if vegaSettings.topBarAddressView {
                windowControls
            }

            if !vegaSettings.topBarAddressView {
                navigationButtons
                urlBar
            }
        }
        .onGeometryChange(for: CGFloat.self) { proxy in
            proxy.size.width
        } action: { newWidth in
            sidebarWidth = newWidth
        }
    }

    private var windowControls: some View {
        SidebarWindowControlsView()
            .environmentObject(browserManager)
            .environment(windowState)
            .padding(.horizontal, VegaDesign.Spacing.sidebarInset)
    }

    private var navigationButtons: some View {
        HStack(spacing: VegaDesign.Spacing.xxs) {
            NavButtonsView(effectiveSidebarWidth: sidebarWidth)
        }
        .padding(.horizontal, VegaDesign.Spacing.sidebarInset)
        .frame(height: VegaDesign.Size.navRow)
    }

    private var urlBar: some View {
        URLBarView(isSidebarHovered: isSidebarHovered)
            .padding(.horizontal, VegaDesign.Spacing.sidebarInset)
    }
}

// MARK: - Sidebar Window Controls (Top Bar Mode)
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
    }
}
