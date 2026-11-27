// Licensed under GPL-3.0. See LICENSE.
//
//  BlockedPopupButton.swift
//  Nook
//
//  Shown in the address field only after a pop-up was blocked: it opens Site Controls, where the row says which.
//

import NookDesign
import NookUI
import NookWeb
import SwiftUI

struct BlockedPopupButton: View {
    @Environment(BrowserWindowState.self) private var windowState
    /// False where the Site Controls button is already there to hang the panel from.
    var anchorsPanel = false

    var body: some View {
        let button = Button("Pop-up Blocked", nookIcon: "macwindow.badge.plus") {
            withAnimation(.interpolatingSpring(Spring(response: 0.3, dampingRatio: 0.86))) {
                windowState.isExtensionLibraryVisible.toggle()
            }
        }
        .labelStyle(.iconOnly)
        .buttonStyle(NookIconButtonStyle(size: NookDesign.Size.iconButton, radius: NookDesign.Radius.sm))
        .foregroundStyle(Color.primary)
        .overlay(alignment: .topTrailing) {
            Circle().fill(.orange).frame(width: 6, height: 6).padding(NookDesign.Spacing.xs).allowsHitTesting(false)
        }
        .help("Pop-up blocked")
        if anchorsPanel {
            button.anchorPreference(key: ExtensionLibraryAnchorKey.self, value: .bounds) { $0 }
        } else {
            button
        }
    }
}
