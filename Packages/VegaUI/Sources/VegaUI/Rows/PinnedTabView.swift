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
    /// Host whose blurred favicon glows behind the tile. Nil for neutral tiles.
    var glowHost: String?
    /// The window is inactive.
    var isDimmed: Bool = false
    var action: () -> Void

    @State private var isHovered: Bool = false
    @State private var glow: CGImage?
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    public init(
        tabName: String,
        tabURL: String,
        tabIcon: Icon,
        isActive: Bool,
        isUnloaded: Bool = false,
        hasLeftPinnedURL: Bool = false,
        onResetToPinnedURL: @escaping () -> Void = {},
        colors: SpaceTheme.TileColors? = nil,
        glowHost: String? = nil,
        isDimmed: Bool = false,
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
        self.glowHost = glowHost
        self.isDimmed = isDimmed
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            ZStack {
                VegaDesign.Radius.shape(VegaDesign.Radius.lg)
                    .fill(backgroundColor)
                    .animation(VegaDesign.Motion.hover(isHovered), value: isHovered)
                if let glow, colors != nil {
                    glowImage(glow)
                        .opacity(VegaDesign.Surface.favoriteGlowOpacity(dark: colorScheme == .dark, hovered: isHovered, dimmed: isDimmed))
                        .clipShape(VegaDesign.Radius.shape(VegaDesign.Radius.lg))
                        .allowsHitTesting(false)
                }
                if isActive, let colors {
                    if let glow, !isDimmed {
                        glowImage(glow)
                            .mask(VegaDesign.Radius.shape(VegaDesign.Radius.lg)
                                .strokeBorder(Color.black, lineWidth: VegaDesign.Size.favoriteBorder))
                            .allowsHitTesting(false)
                    } else {
                        VegaDesign.Radius.shape(VegaDesign.Radius.lg)
                            .strokeBorder(Color(colors.selectedBorder).opacity(isDimmed ? VegaDesign.Surface.favoriteDimmedBorderOpacity : 1),
                                          lineWidth: VegaDesign.Size.favoriteBorder)
                    }
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
        .task(id: wantsGlow ? glowHost : nil) {
            glow = nil
            guard wantsGlow, let glowHost else { return }
            glow = await FaviconGlow.shared.image(forHost: glowHost)
        }
    }

    private var wantsGlow: Bool { colors != nil && !reduceTransparency }

    private func glowImage(_ image: CGImage) -> some View {
        // Fills the tile's own frame; on its own, scaledToFill grows the tile with the sidebar's width.
        Color.clear
            .overlay {
                Image(decorative: image, scale: VegaDesign.Size.favoriteGlowScale)
                    .resizable()
                    .scaledToFill()
            }
            .clipped()
    }

    //MARK: - Colors
    /// Unthemed and selected: clear, since `vegaRowSelection` draws the raised surface.
    private var backgroundColor: Color {
        if let colors {
            if isActive { return VegaDesign.Surface.favoriteSelectedFill(dark: colorScheme == .dark, dimmed: isDimmed) }
            return Color(isHovered ? colors.hoverFill : colors.fill)
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
