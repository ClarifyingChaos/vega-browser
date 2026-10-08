// Licensed under GPL-3.0. See LICENSE.
//
//  View+Surface.swift
//  Vega
//
//  The surface recipes every layer goes through. Vega draws no Liquid Glass: floating layers
//  are solid cards, sidebar chrome and rows are Surface fills.
//

import SwiftUI

public extension View {
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

    /// The selected sidebar row or pinned tile. Branch-free so view identity is stable and the
    /// change animates; the row applies its own `.raised` elevation.
    func vegaRowSelection(_ isSelected: Bool, radius: CGFloat = VegaDesign.Radius.md) -> some View {
        let shape = VegaDesign.Radius.shape(radius)
        return background(shape.fill(isSelected ? VegaDesign.Surface.raised : .clear))
            .overlay(shape.strokeBorder(VegaDesign.Surface.hairline.opacity(isSelected ? 1 : 0), lineWidth: VegaDesign.Size.hairlineWidth))
    }

    /// A sidebar chrome control or group: history, sidebar and AI toggles, bottom bar buttons,
    /// search fields, filter chips. `tint` marks the chosen one of a set.
    func vegaControlSurface<S: InsettableShape>(_ isOn: Bool = true, tint: Color? = nil, in shape: S) -> some View {
        background(shape.fill(isOn ? (tint?.opacity(VegaDesign.Surface.tintOpacity) ?? VegaDesign.Surface.fill) : .clear))
    }
}
