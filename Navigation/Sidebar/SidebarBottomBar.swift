// Licensed under GPL-3.0. See LICENSE.
//
//  SidebarBottomBar.swift
//  Vega
//
//  Created by Aether on 15/11/2025.
//

import SwiftUI
import VegaDesign
import VegaTabsCore
import VegaWeb
import VegaUI

/// Bottom bar of the sidebar containing menu button, spaces list, and new space button
struct SidebarBottomBar: View {
    @EnvironmentObject var browserManager: BrowserManager
    @Environment(TabsController.self) private var tabs
    @Environment(BrowserWindowState.self) private var windowState
    @Binding var isMenuButtonHovered: Bool
    let onMenuTap: () -> Void
    let onNewSpaceTap: () -> Void
    let onMenuHover: (Bool) -> Void
    
    var body: some View {
        HStack(alignment: .center, spacing: VegaDesign.Spacing.xxs) {
            menuButton

            // Hide spaces list in incognito windows (only one ephemeral space)
            if !windowState.isIncognito {
                SpacesList()
                    .frame(maxWidth: .infinity)
                    .environmentObject(browserManager)
                    .environment(windowState)
            }

            // Hide new space button in incognito windows
            if !windowState.isIncognito {
                newSpaceButton
            }
        }
        .frame(height: VegaDesign.Size.bottomBar)
        .padding(.horizontal, VegaDesign.Spacing.sidebarInset)
    }
    
    private var menuButton: some View {
        ZStack {
            Button("Menu", systemImage: "archivebox") {
                onMenuTap()
            }
            .labelStyle(.iconOnly)
            .buttonStyle(VegaIconButtonStyle(radius: VegaDesign.Size.iconButton / 2))
            .foregroundStyle(Color.primary)
            .vegaControlGlass(in: Circle())
            .onHoverTracking { isHovered in
                isMenuButtonHovered = isHovered
                onMenuHover(isHovered)
            }
            
            DownloadIndicator()
                .offset(x: VegaDesign.Spacing.lg, y: -VegaDesign.Spacing.lg)
        }
    }
    
    private var newSpaceButton: some View {
        Menu{
            Button("New Space", systemImage: "square.grid.2x2") {
                onNewSpaceTap()
            }
            
            Button("New Folder", systemImage: "folder.badge.plus") {
                if let spaceID = windowState.spaceID {
                    tabs.createFolderForRename(in: .tabs(spaceID: spaceID), after: nil)
                }
            }
            
            Divider()
            
            Button("New Profile", systemImage: "person.badge.plus") {
                // TODO: Show profile creation dialog
            }
        } label:{
            Label("Actions", systemImage: "plus")
                .labelStyle(.iconOnly)
        }
        .menuStyle(.button)
        .buttonStyle(VegaIconButtonStyle(radius: VegaDesign.Size.iconButton / 2))
        .foregroundStyle(Color.primary)
        .vegaControlGlass(in: Circle())
    }
}
