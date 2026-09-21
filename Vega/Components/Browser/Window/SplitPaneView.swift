// Licensed under GPL-3.0. See LICENSE.
//
//  SplitPaneView.swift
//  Vega
//
//  One pane of the split view: the page, with glass controls floating over it. The compositor keeps
//  panes across refreshes so a web view never leaves its superview while the pair holds.
//

import AppKit
import SwiftUI
import VegaDesign
import VegaTabsCore
import VegaUI
import VegaWeb

final class SplitPaneView: NSView {
    let side: SplitViewManager.Side
    let itemID: UUID
    /// The page view's parent. It fills the pane; the controls float over it.
    let content = NSView()
    private let maskLayer = CAShapeLayer()

    init(frame: NSRect, side: SplitViewManager.Side, itemID: UUID, browserManager: BrowserManager, windowState: BrowserWindowState) {
        self.side = side
        self.itemID = itemID
        super.init(frame: frame)
        wantsLayer = true
        layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        layer?.mask = maskLayer
        content.frame = bounds
        content.autoresizingMask = [.width, .height]
        addSubview(content)

        // Each control is its own hosting view sized to its content, so the rest of the pane
        // passes clicks to the page.
        func host(_ view: some View) -> NSView {
            let host = NSHostingView(rootView: view
                .environment(browserManager.tabs)
                .environment(windowState)
                .environment(\.tabActions, browserManager))
            host.translatesAutoresizingMaskIntoConstraints = false
            host.safeAreaRegions = []
            addSubview(host)
            return host
        }
        let title = host(SplitPaneTitle(itemID: itemID))
        let buttons = host(SplitPaneButtons(itemID: itemID))
        let inset = VegaDesign.Spacing.md
        title.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        NSLayoutConstraint.activate([
            title.topAnchor.constraint(equalTo: topAnchor, constant: inset),
            title.leadingAnchor.constraint(equalTo: leadingAnchor, constant: inset),
            title.trailingAnchor.constraint(lessThanOrEqualTo: buttons.leadingAnchor, constant: -inset),
            buttons.topAnchor.constraint(equalTo: topAnchor, constant: inset),
            buttons.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -inset),
        ])
        updateMask()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    /// Puts `view` in the pane, leaving it alone when it is already there.
    func show(_ view: NSView) {
        if view.superview !== content {
            content.subviews.forEach { $0.removeFromSuperview() }
            content.addSubview(view)
        }
        view.frame = content.bounds
        view.autoresizingMask = [.width, .height]
        view.isHidden = false
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        updateMask()
    }

    private func updateMask() {
        let radius = VegaDesign.Radius.md
        maskLayer.path = TabCompositorWrapper.createUnevenRoundedRectPath(
            rect: bounds,
            topLeadingRadius: side == .left ? 0 : radius,
            bottomLeadingRadius: radius,
            bottomTrailingRadius: radius,
            topTrailingRadius: side == .right ? 0 : radius
        )
    }
}

/// What the pane shows, floating at its top leading corner.
private struct SplitPaneTitle: View {
    let itemID: UUID

    @Environment(TabsController.self) private var tabs
    @Environment(BrowserWindowState.self) private var windowState

    var body: some View {
        if let item = tabs.item(itemID) {
            HStack(spacing: VegaDesign.Spacing.sm) {
                ItemFavicon(item: item, session: tabs.session(for: itemID))
                    .frame(width: VegaDesign.Size.favicon, height: VegaDesign.Size.favicon)
                    .clipShape(VegaDesign.Radius.shape(VegaDesign.Radius.xs))
                Text(tabs.title(for: item))
                    .font(VegaDesign.Font.secondary)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
            }
            .padding(.horizontal, VegaDesign.Spacing.rowPadding)
            .frame(height: VegaDesign.Size.navRow)
            .contentShape(Capsule())
            .onTapGesture { tabs.select(itemID, in: windowState) }
            .vegaGlassEffect(in: Capsule())
        }
    }
}

/// Separate and close, floating at the pane's top trailing corner in one glass capsule.
private struct SplitPaneButtons: View {
    let itemID: UUID

    @Environment(TabsController.self) private var tabs
    @Environment(BrowserWindowState.self) private var windowState
    @Environment(\.tabActions) private var actions

    var body: some View {
        HStack(spacing: VegaDesign.Spacing.xxs) {
            SplitPaneButton(systemImage: "rectangle.split.2x1.slash", help: "Separate Tabs") {
                actions?.separateSplit(in: windowState)
            }
            SplitPaneButton(systemImage: "xmark", help: "Close Tab") {
                tabs.close(itemID)
            }
        }
        .padding(.horizontal, VegaDesign.Spacing.xs)
        .frame(height: VegaDesign.Size.navRow)
        .vegaGlassEffect(in: Capsule())
    }
}

private struct SplitPaneButton: View {
    let systemImage: String
    let help: String
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(VegaDesign.Font.secondary)
                .foregroundStyle(.primary)
                .frame(width: VegaDesign.Size.rowButton, height: VegaDesign.Size.rowButton)
                .background(isHovering ? VegaDesign.Surface.fillPressed : Color.clear)
                .clipShape(VegaDesign.Radius.shape(VegaDesign.Radius.sm))
        }
        .buttonStyle(PlainButtonStyle())
        .help(help)
        .onHoverTracking { isHovering = $0 }
    }
}
