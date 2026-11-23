// Licensed under GPL-3.0. See LICENSE.
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
    /// useAnimations icon (Resources/UseAnimations); plays on hover. Falls back to the SF Symbols above.
    var animation: String? = nil
    var isActive: Bool = true
    let action: () -> Void
    @State private var isHovering: Bool = false
    @State private var shouldWiggle: Bool = false

    private let height: CGFloat = 80

    var body: some View {
        Button {
            action()
            shouldWiggle.toggle()
        } label: {
            label
        }
        .buttonStyle(.plain)
        .onHoverTracking { state in
            isHovering = state
        }
    }

    private var label: some View {
        VStack(spacing: VegaDesign.Spacing.md) {
            Group {
                if let animation {
                    AnimatedIcon(animation, fallback: isActive ? activeImage : image, size: 28, ink: isActive ? Color.accentColor : nil)
                } else {
                    Image(systemName: isActive ? activeImage : image)
                        .font(VegaDesign.Font.titleLarge)
                        .foregroundStyle(isActive ? Color.accentColor : .primary)
                        .symbolRenderingMode(.hierarchical)
                        .symbolEffect(.wiggle, value: shouldWiggle)
                        .contentTransition(.symbolEffect(.replace.magic(fallback: .downUp.byLayer), options: .nonRepeating))
                }
            }

            Text(title)
                .font(VegaDesign.Font.secondary)
                .foregroundStyle(.primary)
        }
        .frame(height: height)
        .frame(maxWidth: .infinity)
        // The chosen tab takes the selected sidebar row's surface, so it takes no hover fill.
        .background(!isActive && isHovering ? VegaDesign.Surface.fill : .clear, in: VegaDesign.Radius.shape(VegaDesign.Radius.xl))
        .contentShape(VegaDesign.Radius.shape(VegaDesign.Radius.xl))
        .vegaRowSelection(isActive, radius: VegaDesign.Radius.xl)
        .animation(VegaDesign.Motion.hover(isHovering), value: isHovering)
        .animation(VegaDesign.Motion.standard, value: isActive)
    }
}
