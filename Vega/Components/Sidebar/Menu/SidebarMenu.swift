// Licensed under GPL-3.0. See LICENSE.
//
//  SidebarMenu.swift
//  Vega
//
//  Created by Maciek Bagiński on 23/09/2025.
//

import AppKit
import SwiftUI
import VegaDesign
import VegaTabsCore
import VegaWeb
import VegaUI
import VegaSettings

struct SidebarMenu: View {
    @Environment(BrowserWindowState.self) private var windowState
    @EnvironmentObject var browserManager: BrowserManager
    @Environment(\.vegaSettings) var vegaSettings

    private let tabColumnWidth: CGFloat = 110

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            if vegaSettings.sidebarPosition == .left{
                tabs
            }
            VStack {
                switch windowState.sidebarMenuSelectedTab {
                case .history:
                    SidebarMenuHistoryTab()
                case .downloads:
                    SidebarMenuDownloadsTab()
                case .spaces:
                    SidebarMenuSpacesTab(onOpenSpace: openSpace, onNewSpace: newSpace)
                case .archive:
                    SidebarMenuArchiveTab(onRestore: close)
                case .media:
                    SidebarMenuMediaTab()
                case .easels:
                    SidebarMenuEaselsTab()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            if vegaSettings.sidebarPosition == .right{
                tabs
            }
        }
        .frame(maxWidth: .infinity)
        .ignoresSafeArea()
    }

    private func close() {
        LibraryMotion.close(windowState)
    }

    private func openSpace(_ id: UUID) {
        close()
        withAnimation(VegaDesign.Motion.standard) {
            browserManager.tabs.setSpace(id, in: windowState)
        }
    }

    private func newSpace() {
        close()
        withAnimation(VegaDesign.Motion.standard) {
            windowState.spaceDraftTheme = .randomPreset()
        }
    }

    var tabs: some View{
        VStack {

            Spacer()
            VStack(spacing: VegaDesign.Spacing.xxl) {
                SidebarMenuTab(
                    image: "clock",
                    activeImage: "clock.fill",
                    title: "History",
                    animation: "clock",
                    isActive: windowState.sidebarMenuSelectedTab == .history,
                    action: {
                        windowState.sidebarMenuSelectedTab = .history
                    }
                )
                if !windowState.isIncognito {
                SidebarMenuTab(
                    image: "archivebox",
                    activeImage: "archivebox.fill",
                    title: "Archive",
                    animation: "archive",
                    isActive: windowState.sidebarMenuSelectedTab == .archive,
                    action: {
                        windowState.sidebarMenuSelectedTab = .archive
                    }
                )
                }
                SidebarMenuTab(
                    image: "square.on.square",
                    activeImage: "square.fill.on.square.fill",
                    title: "Spaces",
                    animation: "grid",
                    isActive: windowState.sidebarMenuSelectedTab == .spaces,
                    action: {
                        windowState.sidebarMenuSelectedTab = .spaces
                    }
                )
                SidebarMenuTab(
                    image: "photo.on.rectangle",
                    activeImage: "photo.on.rectangle.fill",
                    title: "Media",
                    animation: "image",
                    isActive: windowState.sidebarMenuSelectedTab == .media,
                    action: {
                        windowState.sidebarMenuSelectedTab = .media
                    }
                )
                SidebarMenuTab(
                    image: "scribble",
                    activeImage: "scribble.variable",
                    title: "Easels",
                    animation: "edit-2",
                    isActive: windowState.sidebarMenuSelectedTab == .easels,
                    action: {
                        windowState.sidebarMenuSelectedTab = .easels
                    }
                )
                SidebarMenuTab(
                    image: "arrow.down.circle",
                    activeImage: "arrow.down.circle.fill",
                    title: "Downloads",
                    animation: "download",
                    isActive: windowState.sidebarMenuSelectedTab == .downloads,
                    action: {
                        windowState.sidebarMenuSelectedTab = .downloads
                    }
                )
            }
            
            Spacer()
            HStack {
                Button("Back", vegaIcon: "arrow.backward", action: close)
                .vegaIconButtons()
                Spacer()
            }
            .padding(.leading, VegaDesign.Spacing.md)
            .padding(.bottom, VegaDesign.Spacing.md)
        }
        .padding(VegaDesign.Spacing.md)
        .frame(width: tabColumnWidth)
        .frame(maxHeight: .infinity)
        .background(VegaDesign.Surface.fill)
    }
}
