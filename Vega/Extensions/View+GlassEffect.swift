//
//  View+GlassEffect.swift
//  Vega
//

import SwiftUI

extension View {
    @ViewBuilder
    func vegaGlassEffect<S: Shape>(in shape: S) -> some View {
        self.glassEffect(.regular, in: shape)
    }

    @ViewBuilder
    func vegaClearGlassEffect(tint: Color) -> some View {
        self.glassEffect(.regular.tint(tint), in: .circle)
    }
}
