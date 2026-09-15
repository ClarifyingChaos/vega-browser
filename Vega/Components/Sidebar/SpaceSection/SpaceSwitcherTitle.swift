//
//  SpaceSwitcherTitle.swift
//  Vega
//
//  The current space's name in the traffic-light row. Clicking it lists every space by profile.
//

import VegaTabsCore
import SwiftUI

struct SpaceSwitcherTitle: View {
    @EnvironmentObject var browserManager: BrowserManager
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
                    .fixedSize()
                }
            }
        }
    }

    private func label(_ space: SpaceRecord) -> some View {
        let isDropTarget = dragSession.isDragging && dragSession.activeZone == .target(.pinned(spaceID: space.id))
        return Text(space.name)
            .font(VegaDesign.Font.title)
            .foregroundStyle(.primary)
            .lineLimit(1)
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
        let profiles = browserManager.profileManager.profiles
        let grouped = profiles.map { profile in (profile, tabs.spaces(inProfile: profile.id)) }.filter { !$0.1.isEmpty }
        ForEach(grouped, id: \.0.id) { profile, spaces in
            Section(grouped.count > 1 ? profile.name : "") {
                ForEach(spaces) { space in
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
            }
        }
        Divider()
        Button("New Space…", systemImage: "plus", action: onNewSpace)
        Button("Edit Space…", systemImage: "pencil") {
            SpaceEditDialog.present(spaceID: current.id, tabs: tabs, dialogManager: browserManager.dialogManager)
        }
        Button("Profile Settings", systemImage: "gearshape") {
            vegaSettings.currentSettingsTab = .profiles
            openSettings()
        }
    }
}
