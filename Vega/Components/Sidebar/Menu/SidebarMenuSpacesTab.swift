// Licensed under GPL-3.0. See LICENSE.
//
//  SidebarMenuSpacesTab.swift
//  Vega
//
//  The library's Spaces page: every space side by side on its own theme, with its profile,
//  its pinned folders and tabs, and a way into the theme editor. A click opens the space.
//

import SwiftUI
import AppKit
import VegaDesign
import VegaTabsCore
import VegaWeb
import VegaUI

struct SidebarMenuSpacesTab: View {
    @Environment(TabsController.self) private var tabs
    @Environment(BrowserWindowState.self) private var windowState

    let onOpenSpace: (UUID) -> Void
    let onNewSpace: () -> Void

    private let columnWidth: CGFloat = 300
    private let addSize: CGFloat = 32

    @State private var position = ScrollPosition(edge: .leading)
    @State private var scroll: ScrollGeometry?
    @State private var isHovering = false
    @State private var wheelMonitor: Any?

    var body: some View {
        // Arc's layout: each space as a full-height column of its own sidebar, side by side,
        // with a round add button after the last.
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .center, spacing: VegaDesign.Spacing.lg) {
                ForEach(tabs.switchableSpaces(for: windowState).filter { !$0.isAgent }) { space in
                    SpaceColumn(space: space, isCurrent: space.id == windowState.spaceID) {
                        onOpenSpace(space.id)
                    }
                    .frame(width: columnWidth)
                    .frame(maxHeight: .infinity)
                }
                Button(action: onNewSpace) {
                    VegaSymbol("plus", size: 18)
                        .font(.system(size: VegaDesign.Size.spaceIcon, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: addSize, height: addSize)
                        .background(Color.black, in: Circle())
                        .contentShape(Circle())
                }
                .buttonStyle(PressScale())
                .help("New Space")
                .accessibilityLabel("New Space")
            }
            .padding(VegaDesign.Spacing.lg)
        }
        .scrollPosition($position)
        .onScrollGeometryChange(for: ScrollGeometry.self, of: { $0 }) { _, new in scroll = new }
        .onHoverTracking { isHovering = $0 }
        .onAppear { startWheel() }
        .onDisappear { stopWheel() }
    }

    /// Over the columns an up-and-down scroll moves them sideways, never the list inside a space. A mouse
    /// (smooth or notched) only turns up and down; a sideways swipe on a trackpad already scrolls sideways.
    private func startWheel() {
        guard wheelMonitor == nil else { return }
        wheelMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { event in
            guard isHovering, abs(event.scrollingDeltaY) > abs(event.scrollingDeltaX), let scroll else { return event }
            let room = scroll.contentSize.width - scroll.containerSize.width
            guard room > 0 else { return event }
            let step: CGFloat = event.hasPreciseScrollingDeltas ? 1 : 50
            let x = min(max(scroll.contentOffset.x - event.scrollingDeltaY * step, 0), room)
            position.scrollTo(x: x)
            return nil
        }
    }

    private func stopWheel() {
        if let wheelMonitor { NSEvent.removeMonitor(wheelMonitor) }
        wheelMonitor = nil
    }
}

private struct PressScale: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(VegaDesign.Motion.quick, value: configuration.isPressed)
    }
}

private struct SpaceColumn: View {
    @Environment(TabsController.self) private var tabs

    let space: SpaceRecord
    let isCurrent: Bool
    let onOpen: () -> Void

    @State private var isHovering = false
    @State private var showThemeEditor = false

    var body: some View {
        let pinned = tabs.children(of: .pinned(spaceID: space.id))
        let open = tabs.children(of: .tabs(spaceID: space.id))
        VStack(alignment: .leading, spacing: VegaDesign.Spacing.rowGap) {
            header
                .padding(.bottom, VegaDesign.Spacing.md)
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: VegaDesign.Spacing.rowGap) {
                    ForEach(pinned) { item in row(item) }
                    if !pinned.isEmpty && !open.isEmpty {
                        Rectangle()
                            .fill(VegaDesign.Surface.hairline)
                            .frame(height: 1)
                            .padding(.vertical, VegaDesign.Spacing.sm)
                    }
                    ForEach(open) { item in row(item) }
                }
            }
            Spacer(minLength: 0)
            HStack {
                Image(systemName: "arrow.up.and.down.and.arrow.left.and.right")
                Spacer()
                Image(systemName: "ellipsis")
            }
            .font(.system(size: VegaDesign.Size.rowGlyph, weight: .medium))
            .foregroundStyle(.secondary)
            .padding(.horizontal, VegaDesign.Spacing.xs)
            .accessibilityHidden(true)
        }
        .padding(VegaDesign.Spacing.lg)
        .frame(maxHeight: .infinity, alignment: .top)
        .background {
            // Each column on its own space's color, darkened like Arc's so the library reads as one.
            SpaceChromeBackground(theme: space.theme, accent: space.accentColor, isActive: true, blursBehind: false)
                .overlay(Color.black.opacity(0.12))
                .clipShape(VegaDesign.Radius.shape(VegaDesign.Radius.lg))
        }
        .overlay {
            VegaDesign.Radius.shape(VegaDesign.Radius.lg)
                .strokeBorder(isCurrent ? Color.white.opacity(0.35) : Color.clear, lineWidth: 1.5)
        }
        .spaceThemeAppearance(space.theme)
        .scaleEffect(isHovering ? 1.005 : 1)
        .animation(VegaDesign.Motion.hover(isHovering), value: isHovering)
        .contentShape(VegaDesign.Radius.shape(VegaDesign.Radius.lg))
        .onTapGesture(perform: onOpen)
        .onHoverTracking { isHovering = $0 }
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(space.name)
    }

    private var header: some View {
        HStack(spacing: VegaDesign.Spacing.sm) {
            Circle()
                .fill(space.accentColor)
                .frame(width: VegaDesign.Spacing.md, height: VegaDesign.Spacing.md)
            Text(space.name)
                .font(VegaDesign.Font.title)
                .lineLimit(1)
            Spacer(minLength: 0)
            if let profile = tabs.profiles.first(where: { $0.spaceIDs.contains(space.id) }) {
                Label(profile.name, vegaIcon: "person.crop.circle")
                    .font(VegaDesign.Font.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Button("Edit Theme Color…", systemImage: "paintbrush.pointed") { showThemeEditor = true }
                .labelStyle(.iconOnly)
                .buttonStyle(VegaIconButtonStyle(size: VegaDesign.Size.rowButton))
                .foregroundStyle(.secondary)
                .help("Edit Theme Color…")
                .popover(isPresented: $showThemeEditor, arrowEdge: .bottom) {
                    SpaceThemeEditor(space: space)
                        .environment(tabs)
                }
        }
    }

    private func row(_ item: Item) -> some View {
        HStack(spacing: VegaDesign.Spacing.md) {
            if isFolder(item) {
                Image(systemName: "folder.fill")
                    .font(.system(size: VegaDesign.Size.favicon - 2))
                    .foregroundStyle(.primary)
                    .frame(width: VegaDesign.Size.favicon, height: VegaDesign.Size.favicon)
            } else {
                ItemFavicon(item: item, session: tabs.session(for: item.id))
                    .frame(width: VegaDesign.Size.favicon, height: VegaDesign.Size.favicon)
                    .clipShape(VegaDesign.Radius.shape(VegaDesign.Radius.xs))
            }
            Text(tabs.title(for: item))
                .font(VegaDesign.Font.body)
                .fontWeight(isFolder(item) ? .semibold : .regular)
                .lineLimit(1)
        }
        .frame(height: VegaDesign.Size.row)
    }

    private func isFolder(_ item: Item) -> Bool {
        if case .folder = item.kind { return true }
        return false
    }
}
