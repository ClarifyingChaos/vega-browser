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
    @Environment(\.colorScheme) private var colorScheme

    /// A lit edge, brighter at the top as light catches the glass. Over a dark page the glass and
    /// its shadow both go dark too, and without this edge the panel melts into the page.
    private var rim: some View {
        shape.strokeBorder(
            LinearGradient(colors: colorScheme == .dark ? [.white.opacity(0.24), .white.opacity(0.08)]
                                                        : [.black.opacity(0.10), .black.opacity(0.16)],
                           startPoint: .top, endPoint: .bottom),
            lineWidth: VegaDesign.Size.hairlineWidth)
    }

    func body(content: Content) -> some View {
        if reduceTransparency {
            content.vegaFloatingSurface(in: shape)
        } else if #available(macOS 26, iOS 26, *) {
            content
                // Regular, not clear: these panels carry text (HIG, Materials).
                .glassEffect(.regular, in: shape)
                .overlay(rim)
                .vegaElevation(.floating)
        } else {
            content
                .clipShape(shape)
                .background(.regularMaterial, in: shape)
                .overlay(rim)
                .vegaElevation(.floating)
        }
    }
}
