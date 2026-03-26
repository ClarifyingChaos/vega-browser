//
//  View+GlassEffect.swift
//  Vega
//

import SwiftUI

extension View {
    @ViewBuilder
    func vegaGlassEffect<S: Shape>(in shape: S) -> some View {
        if #available(macOS 26.0, *) {
            self.glassEffect(.regular, in: shape)
        } else {
            self.background(.regularMaterial, in: shape)
        }
    }

    @ViewBuilder
    func vegaClearGlassEffect(tint: Color) -> some View {
        if #available(macOS 26.0, *) {
            self.glassEffect(.regular.tint(tint), in: .circle)
        } else {
            self.background(.ultraThinMaterial)
        }
    }
}
