// Licensed under GPL-3.0. See LICENSE.
//
//  TabSuggestionItem.swift
//  Vega
//
//  Created by Maciek Bagiński on 18/08/2025.
//

import SwiftUI
import VegaDesign
import VegaWeb
import VegaUI

struct TabSuggestionItem: View {
    let tab: SearchManager.TabMatch
    var isSelected: Bool = false
    
    @State private var isHovered: Bool = false
    @EnvironmentObject var gradientColorManager: GradientColorManager

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            HStack(spacing: 9) {
                ZStack {
                    tab.favicon
                        .resizable()
                        .scaledToFit()
                        .foregroundStyle(.secondary)
                        .frame(width: 14, height: 14)
                }
                .frame(width: 24, height: 24)
                .background(isSelected ? AnyShapeStyle(.white) : AnyShapeStyle(VegaDesign.Surface.fill))
                .clipShape(
                    VegaDesign.Radius.shape(VegaDesign.Radius.xs)
                )
                Text(tab.title)
                    .font(.system(size: 15, weight: .medium)) // FORK: Arc's row title
                    .foregroundStyle(isSelected ? .white : .primary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            Spacer()
            HStack(spacing: 10) {
                Text(tab.otherSpaceName ?? "Switch to Tab") // FORK: Arc shows the space name for other spaces' tabs
                    .font(VegaDesign.Font.secondary)
                    .foregroundStyle(isSelected ? .white : .secondary)
                ZStack {
                    Image(systemName: "arrow.right")
                        .font(VegaDesign.Font.label)
                        .foregroundStyle(isSelected ? gradientColorManager.accentColor : .secondary)
                        .frame(width: 16, height: 16)
                }
                .frame(width: 24, height: 24)
                .background(isSelected ? .white : VegaDesign.Surface.fill)
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
