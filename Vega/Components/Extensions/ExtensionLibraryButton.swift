// Licensed under GPL-3.0. See LICENSE.
//
//  ExtensionLibraryButton.swift
//  Vega
//

import SwiftUI
import VegaDesign
import VegaWeb
import VegaUI

struct ExtensionLibraryButton: View {
    @EnvironmentObject var browserManager: BrowserManager
    @Environment(BrowserWindowState.self) private var windowState

    var body: some View {
        // Arc's site controls button; the panel springs out of it.
        Button("Site Controls", vegaIcon: "slider.horizontal.3") {
            withAnimation(.interpolatingSpring(Spring(response: 0.3, dampingRatio: 0.86))) {
                windowState.isExtensionLibraryVisible.toggle()
            }
        }
        .labelStyle(.iconOnly)
        .buttonStyle(VegaIconButtonStyle(size: VegaDesign.Size.iconButton, radius: VegaDesign.Radius.sm))
        .foregroundStyle(Color.primary)
        // The overlay in WindowView hangs off this frame.
        .anchorPreference(key: ExtensionLibraryAnchorKey.self, value: .bounds) { $0 }
    }
}
