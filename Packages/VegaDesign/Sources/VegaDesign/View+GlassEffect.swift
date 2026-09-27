// Licensed under GPL-3.0. See LICENSE.
//
//  View+GlassEffect.swift
//  Vega
//
//  The only Liquid Glass entry point in the app. Every floating layer
//  (palette, toast, dialog, find bar, hover sidebar overlay, extension
//  panels, split card) goes through here so there is one recipe, not six.
//

import SwiftUI

public extension View {
    /// Liquid Glass layer that floats over content. Sidebar rows use `vegaRowSelection`.
    /// Untinted: the material samples the page behind it, which is the whole effect. Contrast is
    /// the content's job, so every layer's text uses the roles rather than a fixed colour.
    @ViewBuilder
    func vegaGlassEffect<S: Shape>(in shape: S) -> some View {
        // The clip is not redundant: glassEffect draws the material in `shape` but leaves the
        // content unclipped, so a full-bleed fill inside runs out to the square corners and the
        // shadow traces that square. Clipping here means no call site has to remember.
        self.clipShape(shape)
            .glassEffect(.regular, in: shape)
            .vegaElevation(.floating)
    }

    /// Controls over video, as in the system PiP window: clear glass bends the picture rather
    /// than frosting it, and reacts to the pointer.
    func vegaMediaGlass<S: Shape>(in shape: S) -> some View {
        glassEffect(.clear.interactive(), in: shape)
    }

    @ViewBuilder
    func vegaClearGlassEffect(tint: Color) -> some View {
        self.glassEffect(.regular.tint(tint), in: .circle)
    }

    /// The selected sidebar row or pinned tile. Branch-free (`.identity` when idle) so view
    /// identity is stable and the change animates.
    func vegaRowSelection(_ isSelected: Bool, radius: CGFloat = VegaDesign.Radius.md) -> some View {
        modifier(SidebarGlass(isOn: isSelected, shape: VegaDesign.Radius.shape(radius)))
    }

    /// A sidebar chrome control or group: history, sidebar and AI toggles, bottom bar buttons,
    /// search fields, filter chips. `tint` marks the chosen one of a set, the way prominent
    /// glass buttons are tinted, rather than leaving the others without glass.
    func vegaControlGlass<S: InsettableShape>(_ isOn: Bool = true, tint: Color? = nil, in shape: S) -> some View {
        modifier(SidebarGlass(isOn: isOn, tint: tint, shape: shape))
    }
}

/// Glass inside the sidebar, which is not itself glass.
private struct SidebarGlass<S: InsettableShape>: ViewModifier {
    let isOn: Bool
    var tint: Color? = nil
    let shape: S
    @Environment(\.vegaInsideGlass) private var insideGlass

    func body(content: Content) -> some View {
        content
            // Never glass on glass: inside the hover overlay it keeps a raised fill.
            .background {
                if isOn && insideGlass {
                    shape.fill(VegaDesign.Surface.raised)
                        .overlay(shape.strokeBorder(VegaDesign.Surface.hairline, lineWidth: VegaDesign.Size.hairlineWidth))
                }
            }
            .glassEffect(isOn && !insideGlass ? .regular.tint(tint) : .identity, in: shape)
    }
}

public extension EnvironmentValues {
    /// True for content drawn on a glass layer (the hover sidebar overlay).
    @Entry var vegaInsideGlass: Bool = false
}
