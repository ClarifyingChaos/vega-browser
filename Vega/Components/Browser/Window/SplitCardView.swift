// Licensed under GPL-3.0 with the App Store exception in LICENSE-EXCEPTION.md.
//
//  SplitCardView.swift
//  Vega
//
//  Created by Maciek Bagiński on 09/12/2025.
//

import SwiftUI
import VegaDesign

struct SplitCardView: View {
    var icon: String
    var text: String
    var isTabHovered: Bool
    var accentColor: Color = .blue
    
    private var currentTextColor: Color {
        isTabHovered ? accentColor : .white
    }
    
    var body: some View {
        ZStack {
            VStack(spacing: 12) {
                Image(systemName: icon)
                    .font(VegaDesign.Font.heading)
                    .foregroundStyle(currentTextColor)
                Text(text)
                    .font(VegaDesign.Font.secondary)
                    .lineLimit(1)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(currentTextColor)
                    .frame(maxWidth: .infinity)
            }
            .opacity(0.6)
            
            VegaDesign.Radius.shape(VegaDesign.Radius.lg)
                .strokeBorder(currentTextColor, style: StrokeStyle(lineWidth: 2, dash: [7,10]))
                .opacity(0.3)
        }
        .frame(width: 237, height: 394)
        .padding(8)
        .background(
            Color(currentTextColor)
                .opacity(0.1)
        )
        .vegaGlassEffect(in: VegaDesign.Radius.shape(VegaDesign.Radius.lg))
        .animation(VegaDesign.Motion.standard, value: currentTextColor)
    }
}
