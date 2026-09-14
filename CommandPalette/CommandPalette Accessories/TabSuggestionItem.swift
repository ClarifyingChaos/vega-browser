//
//  TabSuggestionItem.swift
//  Vega
//
//  Created by Maciek Bagiński on 18/08/2025.
//

import SwiftUI

struct TabSuggestionItem: View {
    let tab: Tab
    var isSelected: Bool = false
    
    @State private var isHovered: Bool = false
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var gradientColorManager: GradientColorManager
    
    var body: some View {
        let isDark = colorScheme == .dark
        
        HStack(alignment: .center, spacing: 0) {
            HStack(spacing: 9) {
                ZStack {
                    tab.favicon
                        .resizable()
                        .scaledToFit()
                        .foregroundStyle(.white.opacity(0.5))
                        .frame(width: 14, height: 14)
                }
                .frame(width: 24, height: 24)
                .background(isSelected ? .white : .clear)
                .clipShape(
                    VegaDesign.Radius.shape(VegaDesign.Radius.xs)
                )
                Text(tab.name)
                    .font(VegaDesign.Font.label)
                    .foregroundStyle(isSelected ? .white : isDark ? .white.opacity(0.6) : .black.opacity(0.8))
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            Spacer()
            HStack(spacing: 10) {
                Text("Switch to Tab")
                    .font(VegaDesign.Font.secondary)
                    .foregroundStyle(isSelected ? .white : isDark ? .white.opacity(0.3) : .black.opacity(0.3))
                ZStack {
                    Image(systemName: "arrow.right")
                        .font(VegaDesign.Font.label)
                        .foregroundStyle(isSelected ? gradientColorManager.primaryColor : isDark ? .white.opacity(0.5) : .black.opacity(0.5))
                        .frame(width: 16, height: 16)
                }
                .frame(width: 24, height: 24)
                .background(isSelected ? .white : isDark ? .white.opacity(0.05) : .black.opacity(0.05))
                .clipShape(VegaDesign.Radius.shape(VegaDesign.Radius.xs))

            }
        }
        .frame(maxWidth: .infinity)
        .onHoverTracking { hovering in
            withAnimation(VegaDesign.Motion.quick) {
                isHovered = hovering
            }
        }
    }
}
