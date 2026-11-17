// Licensed under GPL-3.0. See LICENSE.
//
//  SpaceTab.swift
//  Vega
//
//  Created by Maciek Bagiński on 30/07/2025.
//

import SwiftUI
#if os(macOS)
import AppKit
#endif
import VegaDesign
import VegaTabsCore
import VegaWeb

/// One tab row in the sidebar outline.
public struct SpaceTab: View {
    let item: Item
    var menuContext: TabMenuContext = .sidebar
    /// A tab with a trail of child tabs draws a chevron that collapses it, as a folder row does.
    var hasChildren = false

    @State private var isHovering: Bool = false
    @State private var isCloseHovering: Bool = false
    @State private var isResetHovering: Bool = false
    @State private var draftName: String = ""
    @State private var selectedOnPress = false
    @FocusState private var isTextFieldFocused: Bool
    @Environment(BrowserWindowState.self) private var windowState
    @Environment(\.tabActions) private var actions
    @Environment(\.vegaSettings) private var vegaSettings
    private let renameState = SidebarRenameState.shared

    @Environment(TabsController.self) private var tabs
    private var session: PageSession? { tabs.session(for: item.id) }
    private var isRenaming: Bool { renameState.itemID == item.id }
    private var isUnloaded: Bool { session?.isUnloaded ?? true }


    public init(
        item: Item,
        menuContext: TabMenuContext = .sidebar,
        hasChildren: Bool = false
    ) {
        self.item = item
        self.menuContext = menuContext
        self.hasChildren = hasChildren
    }

    /// The folder row's chevron; clicking it collapses the trail without selecting the tab.
    private var trailChevron: some View {
        let isOpen = tabs.isOpen(folder: item.id)
        return Button(action: {
            withAnimation(VegaDesign.Motion.spring) { tabs.toggleFolder(item.id) }
        }) {
            VegaSymbol("chevron.right", size: 15)
                .font(.system(size: VegaDesign.Size.rowGlyph - 1, weight: .medium))
                .foregroundStyle(.tertiary)
                .rotationEffect(.degrees(isOpen ? 90 : 0))
                .animation(VegaDesign.Motion.standard, value: isOpen)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    public var body: some View {
        let title = tabs.title(for: item)
        Button(action: {
            let current = tabs.selectedItemID(in: windowState)
            if clickHolds(.command) {
                windowState.multiSelection.toggle(item.id, current: current)
                return
            }
            if clickHolds(.shift) {
                windowState.multiSelection.extend(to: item.id, rows: tabs.sectionTabIDs(containing: item.id, in: windowState), current: current)
                return
            }
            windowState.multiSelection.clear()
            if selectedOnPress {
                selectedOnPress = false
            } else if isCurrentTab {
                startRename(title)
            } else {
                if isRenaming { commitRename() }
                tabs.select(item.id, in: windowState)
            }
        }) {
            HStack(spacing: VegaDesign.Spacing.md) {
                if hasChildren { trailChevron }
                ItemFavicon(item: item, session: session)
                    .frame(width: VegaDesign.Size.favicon, height: VegaDesign.Size.favicon)
                    .clipShape(VegaDesign.Radius.shape(VegaDesign.Radius.xs))
                    .overlay(alignment: .bottomTrailing) {
                        // The tab DevMCP page tools act on.
                        if tabs.agentItemID == item.id {
                            Image(systemName: "sparkle")
                                .font(VegaDesign.Font.micro)
                                .foregroundStyle(.primary)
                                .padding(VegaDesign.Spacing.xxs / 2)
                                .background(.background, in: Circle())
                                .offset(x: VegaDesign.Spacing.xs, y: VegaDesign.Spacing.xs)
                        }
                    }
                    .opacity(isUnloaded ? VegaDesign.Surface.unloadedOpacity : 1)
                if let session, session.hasAudioContent || session.hasPlayingAudio || session.isAudioMuted {
                    Button(action: { session.toggleMute() }) {
                        AnimatedIcon("volume", fallback: session.isAudioMuted ? "speaker.slash.fill" : "speaker.wave.2.fill",
                                     size: 16, ink: .secondary,
                                     // Reversed on purpose: the icon shows what the button does, so a tab that is
                                     // playing sound shows the slashed speaker (mute) and a muted tab shows sound.
                                     toggled: !session.isAudioMuted)
                    }
                    .buttonStyle(.plain)
                    .help(session.isAudioMuted ? "Unmute" : "Mute")
                }

                if isRenaming {
                    TextField("", text: $draftName)
                        .font(VegaDesign.Tab.font)
                        .foregroundStyle(.primary)
                        .opacity(isUnloaded ? VegaDesign.Surface.unloadedOpacity : 1)
                        .textFieldStyle(.plain)
                        .onSubmit { commitRename() }
                        .onEscapeKey { renameState.itemID = nil }
                        .focused($isTextFieldFocused)
                        .onAppear {
                            if draftName.isEmpty { draftName = title }
                            isTextFieldFocused = true
                        }
                } else {
                    // Hidden shrinkable copy sizes the row; the visible copy is laid out at
                    // full width and faded, so long titles never widen the row.
                    Text(title)
                        .font(VegaDesign.Tab.font)
                        .lineLimit(1)
                        .hidden()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .overlay(alignment: .leading) {
                            label(title)
                                .font(VegaDesign.Tab.font)
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
                                .id(title)
                                .transition(.blurReplace)
                        }
                        // Only a rename animates; a page changing its own title swaps without motion.
                        .animation(VegaDesign.Motion.spring, value: item.customTitle)
                        // On hover the text ends before the close button.
                        .vegaTrailingFade(reserving: isHovering ? VegaDesign.Size.row + (showsReset ? VegaDesign.Size.rowButton : 0) : 0)
                        .textSelection(.disabled)
                        .opacity(isUnloaded ? VegaDesign.Surface.unloadedOpacity : 1)
                        // The row shows a short title; hovering shows the page's full one.
                        .help(title)
                }
            }
            .overlay(alignment: .trailing) {
                if isHovering {
                    HStack(spacing: 0) {
                        // Resets a pinned tab whose page left its pinned URL; sits left of close and fades in with it.
                        if showsReset {
                            Button { tabs.resetToHome(item.id) } label: {
                                VegaSymbol("arrow.uturn.backward", size: 15)
                                    .font(VegaDesign.Font.secondary)
                                    .foregroundStyle(.primary)
                                    .frame(width: VegaDesign.Size.rowButton, height: VegaDesign.Size.rowButton)
                                    .background(isResetHovering ? VegaDesign.Surface.fillPressed : Color.clear)
                                    .clipShape(VegaDesign.Radius.shape(VegaDesign.Radius.sm))
                            }
                            .buttonStyle(.plain)
                            .help("Reset to Pinned URL")
                            .onHoverTracking { isResetHovering = $0 }
                        }
                        // Synced loaded tabs: "-" unloads the page; unloaded synced tabs: "x" removes the item;
                        // tabs section: "x" closes.
                        let useUnload = tabs.isSynced(item.id) && !isUnloaded
                        Button(action: {
                            if useUnload { tabs.unload(item.id) } else { tabs.remove(item.id) }
                            // The next row slides under the pointer; let it show its close button.
                            HoverResync.request(after: VegaDesign.Motion.tabCloseDuration)
                        }) {
                            Group {
                                if useUnload { VegaSymbol("minus", size: 15).font(VegaDesign.Font.secondary) }
                                else { AnimatedIcon("error", fallback: "xmark", size: 14) }
                            }
                                .foregroundColor(.primary)
                                .frame(width: VegaDesign.Size.rowButton, height: VegaDesign.Size.rowButton)
                                .background(isCloseHovering ? VegaDesign.Surface.fillPressed : Color.clear)
                                .clipShape(VegaDesign.Radius.shape(VegaDesign.Radius.sm))
                        }
                        .buttonStyle(PlainButtonStyle())
                        .help(useUnload ? "Unload" : "Close")
                        .onHoverTracking { hovering in
                            isCloseHovering = hovering
                        }
                    }
                }
            }
            .padding(.horizontal, VegaDesign.Spacing.rowPadding)
            .frame(height: VegaDesign.Tab.height)
            .frame(minWidth: 0, maxWidth: .infinity)
            .overlay {
                if isRenaming {
                    VegaDesign.Radius.shape(VegaDesign.Tab.radius)
                        .strokeBorder(accentColor, lineWidth: VegaDesign.Size.hairlineWidth)
                }
            }
            .vegaTabSurface(selected: isCurrentTab || isMultiSelected, hovered: isHovering)
            // Developer Mode on this tab's site, marked as Arc marks it.
            .overlay {
                if vegaSettings.isDeveloperSite(tabs.currentURL(for: item)?.host) {
                    VegaDesign.Radius.shape(VegaDesign.Tab.radius)
                        .strokeBorder(Color.yellow, style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                }
            }
        }
        .buttonStyle(VegaTabButtonStyle(onPress: selectOnPress))
        .padding(.vertical, VegaDesign.Tab.verticalInset)
        .onHoverTracking { hovering in
            withAnimation(VegaDesign.Motion.hover(hovering)) {
                isHovering = hovering
            }
            // Read by the middle-click handler in AppDelegate. Only clear the slot if
            // it still points at this row, so the enter of the next row wins the race
            // against the exit of this one.
            if hovering {
                windowState.hoveredItemID = item.id
            } else if windowState.hoveredItemID == item.id {
                windowState.hoveredItemID = nil
            }
        }
        .onChange(of: isTextFieldFocused) { _, focused in
            if isRenaming && !focused { commitRename() }
        }
        .onChange(of: isRenaming) { _, renaming in
            if renaming { draftName = title }
        }
        .contextMenu {
            TabContextMenu(itemID: item.id, context: menuContext)
                .environment(windowState)
                .environment(tabs)
                .environment(\.tabActions, actions)
        }
    }

    private var accentColor: Color { actions?.accentColor ?? .accentColor }

    /// The row text: tidied (`TidyTitles`), and a search page's site in a softer tone after its query.
    private func label(_ title: String) -> Text {
        let tidy = tabs.tidyTitle(for: item)
        guard tidy.showsSite, let site = tidy.siteName else { return Text(tidy.title) }
        return Text(tidy.title) + Text("  " + site).foregroundColor(.secondary)
    }

    private var isMultiSelected: Bool {
        windowState.multiSelection.contains(item.id) && tabs.selectedItems(in: windowState).contains(item.id)
    }

    /// Whether the key is down for the click being handled.
    private func clickHolds(_ key: EventModifiers) -> Bool {
        #if os(macOS)
        let flags = NSEvent.modifierFlags
        return key == .command ? flags.contains(.command) : flags.contains(.shift)
        #else
        return false
        #endif
    }

    private var isCurrentTab: Bool {
        tabs.selectedItemID(in: windowState) == item.id
    }

    private var showsReset: Bool { tabs.hasLeftHome(item.id) }

    /// A plain press on another tab selects it at once; the release then has nothing to do.
    private func selectOnPress() {
        selectedOnPress = false
        guard !isCurrentTab, !clickHolds(.command), !clickHolds(.shift) else { return }
        windowState.multiSelection.clear()
        selectedOnPress = true
        tabs.select(item.id, in: windowState)
    }

    private func startRename(_ title: String) {
        draftName = title
        renameState.itemID = item.id
        isTextFieldFocused = true
    }

    /// Empty input clears the custom title.
    private func commitRename() {
        guard isRenaming else { return }
        let name = draftName.trimmingCharacters(in: .whitespacesAndNewlines)
        renameState.itemID = nil
        isTextFieldFocused = false
        if name != tabs.title(for: item) || name.isEmpty {
            tabs.rename(item.id, name.isEmpty ? nil : name)
        }
    }
}
