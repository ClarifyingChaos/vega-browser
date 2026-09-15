//
//  PinnedButtonView.swift
//  Vega
//
//  Created by Maciek Bagiński on 30/07/2025.
//

import SwiftUI
import AppKit

struct PinnedTabView<Icon: View>: View {
    var tabName: String
    var tabURL: String
    var tabIcon: Icon
    var isActive: Bool
    var isUnloaded: Bool = false
    /// The favorite's open page has left its pinned URL; hovering shows a reset button.
    var hasLeftPinnedURL: Bool = false
    var onResetToPinnedURL: () -> Void = {}
    var action: () -> Void

    @State private var isHovered: Bool = false

    var body: some View {
        Button(action: action) {
            ZStack {
                VegaDesign.Radius.shape(VegaDesign.Radius.lg)
                    .fill(backgroundColor)
                    .animation(VegaDesign.Motion.quick, value: isHovered)

                tabIcon
                    .frame(height: VegaDesign.Size.essentialsFavicon)
                    .opacity(isUnloaded ? VegaDesign.Surface.unloadedOpacity : 1)

                if isActive {
                    VegaDesign.Radius.shape(VegaDesign.Radius.lg)
                        .strokeBorder(VegaDesign.Surface.hairline, lineWidth: VegaDesign.Size.hairlineWidth)
                }
            }
            .overlay(alignment: .topTrailing) {
                if hasLeftPinnedURL && isHovered {
                    Button(action: onResetToPinnedURL) {
                        Image(systemName: "arrow.uturn.backward")
                            .font(VegaDesign.Font.caption)
                            .foregroundStyle(.secondary)
                            .frame(width: VegaDesign.Size.rowButton, height: VegaDesign.Size.rowButton)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help("Reset to Pinned URL")
                    .padding(VegaDesign.Spacing.xs)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: VegaDesign.Size.essentialsTile)
            .frame(minWidth: VegaDesign.Size.essentialsTile)
            .contentShape(VegaDesign.Radius.shape(VegaDesign.Radius.lg))
            .vegaElevation(isActive ? .raised : .flat)
        }
        .buttonStyle(.plain)
        .onHoverTracking { hovering in
            self.isHovered = hovering
        }
    }

    //MARK: - Colors
    private var backgroundColor: Color {
        isActive ? VegaDesign.Surface.raised : (isHovered ? VegaDesign.Surface.fillPressed : VegaDesign.Surface.fill)
    }
}
