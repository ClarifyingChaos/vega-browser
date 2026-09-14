//
//  PinnedButtonView.swift
//  Vega
//
//  Created by Maciek Bagiński on 30/07/2025.
//

import SwiftUI
import AppKit

struct PinnedTabView: View {
    var tabName: String
    var tabURL: String
    var tabIcon: SwiftUI.Image
    var isActive: Bool
    var isUnloaded: Bool = false
    var action: () -> Void

    @EnvironmentObject var browserManager: BrowserManager
    @State private var isHovered: Bool = false

    var body: some View {
        Button(action: action) {
            ZStack {
                VegaDesign.Radius.shape(VegaDesign.Radius.lg)
                    .fill(backgroundColor)
                    .animation(VegaDesign.Motion.quick, value: isHovered)

                tabIcon
                    .resizable()
                    .interpolation(.high)
                    .antialiased(true)
                    .scaledToFit()
                    .frame(height: VegaDesign.Size.essentialsFavicon)
                    .opacity(isUnloaded ? VegaDesign.Surface.unloadedOpacity : 1)

                if isActive {
                    VegaDesign.Radius.shape(VegaDesign.Radius.lg)
                        .strokeBorder(VegaDesign.Surface.hairline, lineWidth: VegaDesign.Size.hairlineWidth)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: VegaDesign.Size.essentialsTile)
            .frame(minWidth: VegaDesign.Size.essentialsTile)
            .contentShape(VegaDesign.Radius.shape(VegaDesign.Radius.lg))
            .vegaElevation(isActive ? .raised : .flat)
        }
        .buttonStyle(.plain)
        .onHoverTracking { hovering in
            self.isHovered = hovering
        }
    }

    //MARK: - Colors
    private var backgroundColor: Color {
        isActive ? VegaDesign.Surface.raised : (isHovered ? VegaDesign.Surface.fillPressed : VegaDesign.Surface.fill)
    }
}
