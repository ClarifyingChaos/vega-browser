// Licensed under GPL-3.0. See LICENSE.
//
//  SplitHalfLabel.swift
//  VegaUI
//
//  One half of the sidebar's split row: everything but the drag source, which is an
//  AppKit view the app wraps around this.
//

import SwiftUI
import VegaDesign
import VegaTabsCore
import VegaWeb

public struct SplitHalfLabel: View {
    let item: Item

    @State private var isHovering: Bool = false
    @State private var isCloseHovering: Bool = false
    @Environment(TabsController.self) private var tabs
    @Environment(BrowserWindowState.self) private var windowState
    @Environment(\.tabActions) private var actions

    public init(item: Item) {
        self.item = item
    }

    public var body: some View {
        let title = tabs.title(for: item)
        let session = tabs.session(for: item.id)
        Button(action: { tabs.select(item.id, in: windowState) }) {
            HStack(spacing: VegaDesign.Spacing.md) {
                ItemFavicon(item: item, session: session)
                    .frame(width: VegaDesign.Size.favicon, height: VegaDesign.Size.favicon)
                    .clipShape(VegaDesign.Radius.shape(VegaDesign.Radius.xs))
                Text(title)
                    .font(VegaDesign.Tab.font)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer(minLength: VegaDesign.Spacing.xs)
                if isHovering {
                    Button(action: { tabs.close(item.id) }) {
                        Image(systemName: "xmark")
                            .font(VegaDesign.Font.secondary)
                            .foregroundColor(.primary)
                            .frame(width: VegaDesign.Size.rowButton, height: VegaDesign.Size.rowButton)
                            .background(isCloseHovering ? VegaDesign.Surface.fillPressed : Color.clear)
                            .clipShape(VegaDesign.Radius.shape(VegaDesign.Radius.sm))
                    }
                    .buttonStyle(PlainButtonStyle())
                    .onHoverTracking { state in
                        isCloseHovering = state
                    }
                }
            }
            .padding(.horizontal, VegaDesign.Spacing.rowPadding)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .onHoverTracking { hovering in
            withAnimation(VegaDesign.Motion.hover(hovering)) {
                isHovering = hovering
            }
        }
        .contextMenu {
            TabContextMenu(itemID: item.id, context: .split)
                .environment(windowState)
                .environment(tabs)
                .environment(\.tabActions, actions)
        }
        .background(isHovering ? VegaDesign.Surface.fill : Color.clear)
    }
}
