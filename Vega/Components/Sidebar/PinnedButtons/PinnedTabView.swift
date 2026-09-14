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

    // Stroke overlay tunables
    private let faviconScale: CGFloat = 6.0      // favicon scale to fit the ring
    private let faviconBlur: CGFloat = 30.0      // blur applied to favicon

    var body: some View {
        Button(action: action) {
            ZStack {
                ZStack {
                    VegaDesign.Radius.shape(VegaDesign.Radius.lg)
                        .fill(
                            backgroundColor
                        )
                        .animation(VegaDesign.Motion.quick, value: isHovered)
                        .overlay {
                            if isActive {
                                tabIcon
                                    .blur(radius: 30)
                                    .opacity(0.5)
                            }

                        }
                }
                .clipShape(VegaDesign.Radius.shape(VegaDesign.Radius.lg))


                HStack {
                    Spacer()
                    VStack {
                        Spacer()
                        tabIcon
                            .resizable()
                            .interpolation(.high)
                            .antialiased(true)
                            .scaledToFit()
                            .frame(height: VegaDesign.Size.essentialsFavicon)
                            .opacity(isUnloaded ? 0.5 : 1.0)
                        Spacer()
                    }

                    Spacer()
                }


                // Favicon-based stroke overlay
                if isActive {
                    faviconStrokeOverlay(
                        corner: VegaDesign.Radius.lg,
                        thickness: VegaDesign.Size.essentialsStroke,
                        scale: faviconScale,
                        blur: faviconBlur
                    )
                    .allowsHitTesting(false)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: VegaDesign.Size.essentialsTile)
            .frame(minWidth: VegaDesign.Size.essentialsTile)
            .contentShape(VegaDesign.Radius.shape(VegaDesign.Radius.lg))
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

    // MARK: - Favicon stroke overlay

    private func faviconStrokeOverlay(
        corner: CGFloat,
        thickness: CGFloat,
        scale: CGFloat,
        blur: CGFloat
    ) -> some View {
        GeometryReader { proxy in
            let size = proxy.size
            let outerRect = VegaDesign.Radius.shape(corner - (thickness))
            let innerRect = VegaDesign.Radius.shape(max(0, corner - (thickness)))

            ZStack {
                let ringMask = ZStack {
                    outerRect
                        .fill(Color.white)

                    innerRect
                        .inset(by: thickness)
                        .fill(Color.black)
                        .compositingGroup()
                        .blendMode(.destinationOut)
                }

                tabIcon
                    .resizable()
                    .interpolation(.high)
                    .antialiased(true)
                    .scaledToFit()
                    .frame(
                        width: min(size.width, size.height) * scale,
                        height: min(size.width, size.height) * scale
                    )
                    .blur(radius: blur)
                    .frame(width: size.width, height: size.height)
                    .mask(ringMask.frame(width: size.width, height: size.height))
            }
        }
    }
}
