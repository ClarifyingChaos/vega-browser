// Licensed under GPL-3.0. See LICENSE.
//
//  AISidebarResizeView.swift
//  Nook
//
//  Resize handle for the AI assistant sidebar.
//  FORK: the same native handle as the main sidebar's (full height, same line and fade), not a
//  separate short SwiftUI line.
//

import SwiftUI
import NookDesign
import NookWeb
import NookUI
import NookSettings

struct AISidebarResizeView: View {
    @EnvironmentObject var browserManager: BrowserManager
    @Environment(BrowserWindowState.self) private var windowState
    @Environment(\.nookSettings) var nookSettings
    @Environment(\.nookUsesDefaultSpaceTheme) private var usesDefaultTheme
    @Environment(\.colorScheme) private var colorScheme
    @State private var startingWidth: CGFloat = 0
    @State private var sessionID = UUID().uuidString

    private let minWidth: CGFloat = 260
    private let maxWidth: CGFloat = 520
    private let standardWidth: CGFloat = 350

    /// The AI panel is always on the right, whichever side the tab sidebar is on.
    private let aiSitsOnRight = true

    private var indicatorColor: NSColor {
        if usesDefaultTheme {
            return NSColor(colorScheme == .dark
                ? NookDesign.SidebarChrome.defaultResizeDark
                : NookDesign.SidebarChrome.defaultResizeLight)
        }
        return NSColor(browserManager.accentColor).withAlphaComponent(0.8)
    }

    var body: some View {
        SidebarResizeHandle(
            color: indicatorColor,
            // The gap is on this handle's leading side when the panel is on the right.
            sidebarOnLeft: !aiSitsOnRight,
            onHover: { _ in },
            onStart: {
                guard windowState.isSidebarAIChatVisible,
                      DragLockManager.shared.startDrag(ownerID: sessionID) else { return false }
                startingWidth = windowState.aiSidebarWidth
                return true
            },
            onDrag: { delta, _ in
                let width = startingWidth + delta * (aiSitsOnRight ? -1 : 1)
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    windowState.aiSidebarWidth = max(minWidth, min(maxWidth, width))
                }
            },
            onEnd: { DragLockManager.shared.endDrag(ownerID: sessionID) },
            onReset: { windowState.aiSidebarWidth = standardWidth }
        )
        // Spans the 8 pt gap beside the page plus 4 pt of the panel, like the main sidebar's handle.
        .frame(width: 12)
        .offset(x: aiSitsOnRight ? -8 : 8)
        .padding(.vertical, 10)
        .onDisappear { DragLockManager.shared.endDrag(ownerID: sessionID) }
    }
}
