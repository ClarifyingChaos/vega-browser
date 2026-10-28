// Licensed under GPL-3.0. See LICENSE.
//
//  PinnedButtonView.swift
//  Vega
//
//  Created by Maciek Bagiński on 30/07/2025.
//

import SwiftUI
import VegaDesign
import VegaTabsCore

public struct PinnedTabView<Icon: View>: View {
    var tabName: String
    var tabURL: String
    var tabIcon: Icon
    var isActive: Bool
    var isUnloaded: Bool = false
    /// The favorite's open page has left its pinned URL; hovering shows a reset button.
    var hasLeftPinnedURL: Bool = false
    var onResetToPinnedURL: () -> Void = {}
    /// The space theme's tile colors, as in Arc. Nil falls back to the neutral fills.
    var colors: SpaceTheme.TileColors?
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
        colors: SpaceTheme.TileColors? = nil,
        action: @escaping () -> Void
    ) {
        self.tabName = tabName
        self.tabURL = tabURL
        self.tabIcon = tabIcon
        self.isActive = isActive
        self.isUnloaded = isUnloaded
        self.hasLeftPinnedURL = hasLeftPinnedURL
        self.onResetToPinnedURL = onResetToPinnedURL
        self.colors = colors
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            ZStack {
                VegaDesign.Radius.shape(VegaDesign.Radius.lg)
                    .fill(backgroundColor)
                    .animation(VegaDesign.Motion.quick, value: isHovered)
                if isActive, let colors {
                    VegaDesign.Radius.shape(VegaDesign.Radius.lg)
                        .strokeBorder(Color(colors.selectedBorder), lineWidth: VegaDesign.Size.favoriteBorder)
                }

                tabIcon
                    .frame(height: VegaDesign.Size.essentialsFavicon)
                    .opacity(isUnloaded ? VegaDesign.Surface.unloadedOpacity : 1)
            }
            .overlay(alignment: .topTrailing) {
                if hasLeftPinnedURL && isHovered {
                    Button(action: onResetToPinnedURL) {
                        Image(systemName: "arrow.uturn.backward")
                            .font(VegaDesign.Font.caption)
                            .foregroundStyle(.primary)
                            .frame(width: VegaDesign.Size.cornerButton, height: VegaDesign.Size.cornerButton)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help("Reset to Pinned URL")
                    .padding(VegaDesign.Spacing.xxs)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: VegaDesign.Size.favoriteTile)
            .frame(minWidth: VegaDesign.Size.favoriteTile)
            .contentShape(VegaDesign.Radius.shape(VegaDesign.Radius.lg))
            .modifier(TileSelection(isActive: isActive, themed: colors != nil))
        }
        .buttonStyle(.plain)
        .onHoverTracking { hovering in
            self.isHovered = hovering
        }
    }

    //MARK: - Colors
    /// Unthemed and selected: clear, since `vegaRowSelection` draws the raised surface.
    private var backgroundColor: Color {
        if let colors {
            return Color(isActive ? colors.selectedFill : (isHovered ? colors.hoverFill : colors.fill))
        }
        return isActive ? .clear : (isHovered ? VegaDesign.Surface.fillPressed : VegaDesign.Surface.fill)
    }
}

/// A themed tile is flat: fill and border only, no blur, no shadow. Without a theme it keeps
/// the raised selection.
private struct TileSelection: ViewModifier {
    let isActive: Bool
    let themed: Bool

    func body(content: Content) -> some View {
        if themed {
            content
        } else {
            content
                .vegaRowSelection(isActive, radius: VegaDesign.Radius.lg)
                .vegaElevation(isActive ? .raised : .flat)
        }
    }
}
