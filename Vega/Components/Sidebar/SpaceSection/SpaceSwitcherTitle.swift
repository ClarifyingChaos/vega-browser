// Licensed under GPL-3.0. See LICENSE.
//
//  SpaceSwitcherTitle.swift
//  Vega
//
//  The current space's name in the traffic-light row. Clicking it lists every space.
//

import SwiftUI
import VegaDesign
import VegaTabsCore
import VegaWeb
import VegaUI

struct SpaceSwitcherTitle: View {
    @Environment(TabsController.self) private var tabs
    @Environment(BrowserWindowState.self) private var windowState
    @Environment(\.vegaSettings) private var vegaSettings
    @Environment(\.openSettings) private var openSettings
    @ObservedObject private var dragSession = VegaDragSessionManager.shared
    @State private var isHovering = false

    let onNewSpace: () -> Void

    private var currentSpace: SpaceRecord? {
        windowState.spaceID.flatMap { tabs.space($0) }
    }

    var body: some View {
        if let space = currentSpace {
            // Also the pin target for a space whose pinned section is empty.
            let pinned = Parent.pinned(spaceID: space.id)
            VegaDropZoneHostView(zoneID: .target(pinned), manager: dragSession, onDrop: { itemID in
                tabs.pin(itemID, to: pinned)
            }) {
                if windowState.privateTree != nil {
                    label(space)
                } else {
                    Menu {
                        menuContent(current: space)
                    } label: {
                        label(space)
                    }
                    .menuStyle(.button)
                    .buttonStyle(.plain)
                    .menuIndicator(.hidden)
                    // Width may shrink so a long name truncates beside the history buttons.
                    .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func label(_ space: SpaceRecord) -> some View {
        let isDropTarget = dragSession.isDragging && dragSession.activeZone == .target(.pinned(spaceID: space.id))
        let title = HStack(spacing: VegaDesign.Spacing.xs) {
            if space.isAgent {
                Image(systemName: "sparkles").foregroundStyle(VegaDesign.Surface.agentGradient)
            }
            Text(space.name).foregroundStyle(.primary)
        }
            .font(VegaDesign.Font.label)
            .lineLimit(1)
            .fixedSize()
        // A name too long for the title row fades out, the way a tab row's title does.
        return ViewThatFits(in: .horizontal) {
            title
            title
                .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                .vegaTrailingFade()
        }
        .padding(.horizontal, VegaDesign.Spacing.sm)
        .frame(height: VegaDesign.Size.row)
        .background(
            VegaDesign.Radius.shape(VegaDesign.Radius.md)
                .fill(isHovering || isDropTarget ? VegaDesign.Surface.fill : Color.clear)
        )
        .contentShape(VegaDesign.Radius.shape(VegaDesign.Radius.md))
        .onHoverTracking { isHovering = $0 }
    }

    @ViewBuilder
    private func menuContent(current: SpaceRecord) -> some View {
        ForEach(tabs.orderedSpaces) { space in
            Button {
                tabs.setSpace(space.id, in: windowState)
            } label: {
                if space.id == current.id {
                    Label(space.name, systemImage: "checkmark")
                } else {
                    Text(space.name)
                }
            }
        }
        Divider()
        Button("New Space…", systemImage: "plus", action: onNewSpace)
        Button("Space Settings", systemImage: "gearshape") {
            SettingsNavigation.shared.currentSettingsTab = .spaces
            openSettings()
        }
    }
}
