// Licensed under GPL-3.0. See LICENSE.
//
//  View+Surface.swift
//  Vega
//
//  The surface recipes every layer goes through. Vega draws no Liquid Glass: floating layers
//  are solid cards, sidebar chrome and rows are Surface fills.
//

import SwiftUI

private struct DefaultSpaceThemeKey: EnvironmentKey {
    static let defaultValue = false
}

public extension EnvironmentValues {
    /// True while the chrome shows a space with no custom theme.
    var vegaUsesDefaultSpaceTheme: Bool {
        get { self[DefaultSpaceThemeKey.self] }
        set { self[DefaultSpaceThemeKey.self] = newValue }
    }
}

public extension View {
    /// A soft page-frame shadow, drawn separately from live WebKit content.
    /// Removing the silhouette's fill keeps split gutters transparent to the window theme.
    func vegaWebPageShadow<S: Shape>(in shape: S, enabled: Bool = true) -> some View {
        background {
            if enabled {
                shape.fill(Color.black)
                    .shadow(color: .black.opacity(0.20), radius: 6, x: 0, y: 2)
                    .shadow(color: .black.opacity(0.08), radius: 1, x: 0, y: 0)
                    .overlay {
                        shape.fill(Color.black).blendMode(.destinationOut)
                    }
                    // Only the shadow is composited; the page and its video layers
                    // remain outside this group.
                    .compositingGroup()
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
    }

    /// A layer that floats over content: solid raised card, hairline edge, floating shadow.
    func vegaFloatingSurface<S: InsettableShape>(in shape: S) -> some View {
        self.clipShape(shape)
            .background(shape.fill(VegaDesign.Surface.raised))
            .overlay(shape.strokeBorder(VegaDesign.Surface.hairline, lineWidth: VegaDesign.Size.hairlineWidth))
            .vegaElevation(.floating)
    }

    /// Controls over video: a dark scrim, whatever the page or appearance.
    func vegaMediaControl<S: Shape>(in shape: S) -> some View {
        background(shape.fill(VegaDesign.Surface.mediaScrim))
    }

    /// The selected sidebar row or pinned tile: Arc's translucent white, no outline, so the
    /// space's color carries through. Branch-free so view identity is stable and the change
    /// animates; the row applies its own `.raised` elevation.
    func vegaRowSelection(_ isSelected: Bool, radius: CGFloat = VegaDesign.Radius.md) -> some View {
        background(VegaDesign.Radius.shape(radius).fill(isSelected ? VegaDesign.Surface.selection : .clear))
    }

    /// A sidebar chrome control or group: history, sidebar and AI toggles, bottom bar buttons,
    /// search fields, filter chips. `tint` marks the chosen one of a set.
    func vegaControlSurface<S: InsettableShape>(_ isOn: Bool = true, tint: Color? = nil, in shape: S) -> some View {
        background(shape.fill(isOn ? (tint?.opacity(VegaDesign.Surface.tintOpacity) ?? VegaDesign.Surface.fill) : .clear))
    }
}

/// Native tab interaction; Reduce Motion keeps the pressed card at its original scale.
public struct VegaTabButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? VegaDesign.Tab.pressScale : 1)
            .animation(reduceMotion ? nil : VegaDesign.Motion.quick, value: configuration.isPressed)
    }
}

public extension View {
    /// Tab card shared by sidebar rows, split rows and native drag previews: the theme-tinted
    /// selection fill, a hover fill, and a continuous `Tab.radius` shape.
    func vegaTabSurface(selected: Bool, hovered: Bool = false) -> some View {
        let shape = VegaDesign.Radius.shape(VegaDesign.Tab.radius)
        return clipShape(shape)
            .background(shape.fill(selected ? VegaDesign.Surface.selection : hovered ? VegaDesign.Surface.fill : .clear))
            .contentShape(shape)
    }
}
