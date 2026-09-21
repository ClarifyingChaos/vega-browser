// Licensed under GPL-3.0 with the App Store exception in LICENSE-EXCEPTION.md.
//
//  SidebarMenuTab.swift
//  Vega
//
//  Created by Maciek Bagiński on 23/09/2025.
//

import SwiftUI
import VegaDesign
import VegaWeb
import VegaUI

struct SidebarMenuTab: View {
    var image: String
    var activeImage: String
    var title: String
    var isActive: Bool = true
    let action: () -> Void
    @State private var isHovering: Bool = false
    @State private var shouldWiggle: Bool = false

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: isActive ? activeImage : image)
                .font(VegaDesign.Font.titleLarge)
                .foregroundStyle(isActive ? .green : .primary)
                .symbolRenderingMode(.hierarchical)
                .symbolEffect(.wiggle, value: shouldWiggle)
                .contentTransition(.symbolEffect(.replace.magic(fallback: .downUp.byLayer), options: .nonRepeating))

            Text(title)
                .font(VegaDesign.Font.secondary)
                .foregroundStyle(.primary)
        }
        .frame(height: 80)
        .frame(maxWidth: .infinity)
        .background(isActive ? VegaDesign.Surface.fillPressed : isHovering ? VegaDesign.Surface.fill : .clear)
        .animation(VegaDesign.Motion.quick, value: isHovering)
        .animation(VegaDesign.Motion.standard, value: isActive)
        .clipShape(VegaDesign.Radius.shape(VegaDesign.Radius.xl))
        .onHoverTracking { state in
            isHovering = state
        }
        .onTapGesture {
            action()
            shouldWiggle.toggle()
        }
    }
}
