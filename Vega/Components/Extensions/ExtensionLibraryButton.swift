// Licensed under GPL-3.0 with the App Store exception in LICENSE-EXCEPTION.md.
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
        Button("More", systemImage: "ellipsis") {
            windowState.isExtensionLibraryVisible.toggle()
        }
        .labelStyle(.iconOnly)
        .buttonStyle(VegaIconButtonStyle(size: VegaDesign.Size.iconButton, radius: VegaDesign.Radius.sm))
        .foregroundStyle(Color.primary)
        // The overlay in WindowView hangs off this frame.
        .anchorPreference(key: ExtensionLibraryAnchorKey.self, value: .bounds) { $0 }
    }
}
