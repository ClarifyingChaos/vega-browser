// Licensed under GPL-3.0. See LICENSE.
//
//  SidebarWhatsNewCard.swift
//  Vega
//
//  Created by Bain Gurley on 22/09/2026.
//

import SwiftUI
import VegaDesign
import VegaUI
import VegaWeb

/// Shown once after an update, in the update notification's slot. The whole card opens the
/// Updates page in Settings; the corner button dismisses it. Either way it is gone until the next version.
struct SidebarWhatsNewCard: View {
    @EnvironmentObject var browserManager: BrowserManager
    @State private var isHovering = false

    var body: some View {
        // The update card owns this slot while an update is pending.
        if let version = browserManager.whatsNewVersion, browserManager.updateAvailability == nil {
            Button {
                browserManager.openSettings(tab: .updates)
                browserManager.whatsNewVersion = nil
            } label: {
                VStack(spacing: VegaDesign.Spacing.xxs) {
                    Text("What's new in Vega \(version)")
                        .font(VegaDesign.Font.secondary)
                        .foregroundStyle(.primary)
                    Text("See what changed")
                        .font(VegaDesign.Font.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, VegaDesign.Spacing.lg)
                .padding(.vertical, VegaDesign.Spacing.md)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .overlay(alignment: .topTrailing) {
                if isHovering {
                    Button {
                        browserManager.whatsNewVersion = nil
                    } label: {
                        VegaSymbol("xmark", size: 12)
                            .font(VegaDesign.Font.micro)
                            .foregroundStyle(.secondary)
                            .frame(width: VegaDesign.Size.cornerButton, height: VegaDesign.Size.cornerButton)
                    }
                    .buttonStyle(.plain)
                    .padding(VegaDesign.Spacing.xs)
                }
            }
            .vegaFloatingSurface(in: VegaDesign.Radius.shape(VegaDesign.Radius.lg))
            .onHoverTracking { isHovering = $0 }
            .animation(VegaDesign.Motion.quick, value: isHovering)
            .transition(.opacity.combined(with: .move(edge: .bottom)))
        }
    }
}
