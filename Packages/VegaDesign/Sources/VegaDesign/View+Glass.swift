// Licensed under GPL-3.0. See LICENSE.
//
//  View+Glass.swift
//  VegaDesign
//
//  The translucent glass layer for panels that float over the window: Liquid Glass on macOS 26
//  and later, a blur material before that, and the solid raised card when the user turns on
//  Reduce Transparency.
//

import SwiftUI

public extension View {
    /// A floating panel drawn as glass, so the page and sidebar show through it.
    func vegaGlassSurface<S: InsettableShape>(in shape: S) -> some View {
        modifier(VegaGlassSurface(shape: shape))
    }
}

private struct VegaGlassSurface<S: InsettableShape>: ViewModifier {
    let shape: S
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    func body(content: Content) -> some View {
        if reduceTransparency {
            content.vegaFloatingSurface(in: shape)
        } else if #available(macOS 26, iOS 26, *) {
            content
                .glassEffect(.regular, in: shape)
                .vegaElevation(.floating)
        } else {
            content
                .clipShape(shape)
                .background(.regularMaterial, in: shape)
                .overlay(shape.strokeBorder(VegaDesign.Surface.hairline, lineWidth: VegaDesign.Size.hairlineWidth))
                .vegaElevation(.floating)
        }
    }
}
