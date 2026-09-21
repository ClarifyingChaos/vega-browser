// Licensed under GPL-3.0. See LICENSE.
//
//  PinnedButtonView.swift
//  Vega
//
//  Created by Maciek Bagiński on 30/07/2025.
//

import SwiftUI
import VegaDesign

public struct PinnedTabView<Icon: View>: View {
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

    public init(
        tabName: String,
        tabURL: String,
        tabIcon: Icon,
        isActive: Bool,
        isUnloaded: Bool = false,
        hasLeftPinnedURL: Bool = false,
        onResetToPinnedURL: @escaping () -> Void = {},
        action: @escaping () -> Void
    ) {
        self.tabName = tabName
        self.tabURL = tabURL
        self.tabIcon = tabIcon
        self.isActive = isActive
        self.isUnloaded = isUnloaded
        self.hasLeftPinnedURL = hasLeftPinnedURL
        self.onResetToPinnedURL = onResetToPinnedURL
        self.action = action
    }

    public var body: some View {
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
                            .frame(width: VegaDesign.Size.cornerButton, height: VegaDesign.Size.cornerButton)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help("Reset to Pinned URL")
                    .padding(VegaDesign.Spacing.xxs)
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
