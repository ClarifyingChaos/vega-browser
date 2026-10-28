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

/// Header section of the sidebar (space name, URL bar). Back, forward and
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
            .padding(.horizontal, VegaDesign.Spacing.sidebarInset)
    }

    private var urlBar: some View {
        URLBarView(isSidebarHovered: isSidebarHovered)
            .padding(.horizontal, VegaDesign.Spacing.sidebarInset)
    }
}

// MARK: - Space name row
/// The space name, which opens the space list. The sidebar toggle sits in the title row beside
/// the traffic lights.
struct SidebarWindowControlsView: View {
    let onNewSpace: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            SpaceSwitcherTitle(onNewSpace: onNewSpace)
                .layoutPriority(1)
            Spacer(minLength: 0)
        }
        .frame(height: VegaDesign.Size.chromeControl)
    }
}
