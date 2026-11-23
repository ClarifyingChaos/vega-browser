// Licensed under GPL-3.0. See LICENSE.
//
//  PagePreviewOverlay.swift
//  Vega
//
//  FORK: the card beside a sidebar tab or favorite the pointer rests on: the page's last picture, its title and its
//  address. It replaces the plain tooltip, which only repeated the name or link.
//

import SwiftUI
import VegaDesign
import VegaTabsCore
import VegaUI
import VegaWeb

struct PagePreviewOverlay: View {
    let anchors: [UUID: Anchor<CGRect>]

    @Environment(TabsController.self) private var tabs
    @Environment(BrowserWindowState.self) private var windowState

    /// The row the card is up for, and the pending timer that will raise it.
    @State private var shownID: UUID?
    @State private var pending: Task<Void, Never>?

    private let cardWidth: CGFloat = 264
    /// Taller than any card, so one near the window's bottom edge is moved up enough.
    private let cardHeightGuess: CGFloat = 250
    private static let restDelay: Duration = .milliseconds(550)
    private static let switchDelay: Duration = .milliseconds(120)

    private var hoveredID: UUID? { anchors.keys.first }

    var body: some View {
        GeometryReader { proxy in
            if let id = shownID, let anchor = anchors[id], let item = tabs.item(id) {
                let row = proxy[anchor]
                let edge = VegaDesign.Spacing.md
                let onLeft = row.midX < proxy.size.width / 2
                let x = onLeft ? row.maxX + edge : row.minX - cardWidth - edge
                let y = min(max(edge, row.midY - cardHeightGuess / 2), max(edge, proxy.size.height - cardHeightGuess - edge))
                card(for: item)
                    .frame(width: cardWidth)
                    .offset(x: max(edge, x), y: y)
                    .transition(.opacity)
                    .allowsHitTesting(false)
            }
        }
        .animation(VegaDesign.Motion.quick, value: shownID)
        .onChange(of: hoveredID) { _, id in schedule(id) }
    }

    private func schedule(_ id: UUID?) {
        pending?.cancel()
        guard let id, id != windowState.selectedItemID else { shownID = nil; return }
        let delay = shownID == nil ? Self.restDelay : Self.switchDelay
        pending = Task {
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled, hoveredID == id else { return }
            shownID = id
        }
        // Moving off a row takes its card down at once; only raising one waits.
        if hoveredID == nil { shownID = nil }
    }

    @ViewBuilder
    private func card(for item: Item) -> some View {
        let session = tabs.session(for: item.id)
        let title = tabs.title(for: item)
        let address = tabs.currentURL(for: item)
        VStack(alignment: .leading, spacing: 0) {
            Group {
                if let snapshot = session?.switcherSnapshot {
                    Image(nsImage: snapshot)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    ZStack {
                        Rectangle().fill(.quaternary)
                        ItemFavicon(item: item, session: session)
                            .frame(width: 36, height: 36)
                    }
                }
            }
            .frame(width: cardWidth, height: cardWidth * 0.62)
            .clipped()

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(VegaDesign.Font.label)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                if let host = address?.host {
                    Text(host)
                        .font(VegaDesign.Font.secondary)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
        .clipShape(VegaDesign.Radius.shape(VegaDesign.Radius.lg))
        .vegaFloatingSurface(in: VegaDesign.Radius.shape(VegaDesign.Radius.lg))
    }
}
