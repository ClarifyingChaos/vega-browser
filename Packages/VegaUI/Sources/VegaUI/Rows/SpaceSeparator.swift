//
//  SpaceSeparator.swift
//  Vega
//
//  Created by Maciek Bagiński on 30/07/2025.
//
import SwiftUI
import VegaDesign

public struct SpaceSeparator: View {
    @Binding var isHovering: Bool
    let onClear: () -> Void
    let onOrganize: (() -> Void)?
    let isOrganizing: Bool
    let tabCount: Int
    @State private var isClearHovered: Bool = false
    @State private var isOrganizeHovered: Bool = false

    public init(
        isHovering: Binding<Bool>,
        onClear: @escaping () -> Void,
        onOrganize: (() -> Void)?,
        isOrganizing: Bool,
        tabCount: Int
    ) {
        self._isHovering = isHovering
        self.onClear = onClear
        self.onOrganize = onOrganize
        self.isOrganizing = isOrganizing
        self.tabCount = tabCount
    }

    public var body: some View {
        let hasTabs = tabCount > 0
        HStack(spacing: 0) {
            Capsule()
                .fill(VegaDesign.Surface.hairline)
                .frame(height: VegaDesign.Size.hairlineWidth)
                .padding(.horizontal, VegaDesign.Spacing.md)
                .animation(VegaDesign.Motion.quick, value: isHovering)

            // Organize button (trailing side)
            if hasTabs && tabCount >= 5 && isHovering {
                if isOrganizing {
                    ProgressView()
                        .controlSize(.mini)
                        .padding(.horizontal, VegaDesign.Spacing.xs)
                        .transition(.blur.animation(VegaDesign.Motion.quick))
                } else if let onOrganize {
                    Button(action: onOrganize) {
                        HStack(spacing: VegaDesign.Spacing.xs) {
                            Image(systemName: "wand.and.stars")
                                .font(VegaDesign.Font.caption)
                            Text("Organize")
                                .font(VegaDesign.Font.caption)
                        }
                        .foregroundStyle(isOrganizeHovered ? .primary : .tertiary)
                        .padding(.horizontal, VegaDesign.Spacing.xs)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help("Organize tabs with AI")
                    .transition(.blur.animation(VegaDesign.Motion.quick))
                    .onHoverTracking { state in
                        isOrganizeHovered = state
                    }
                }
            }

            // Clear button (trailing side)
            if hasTabs && isHovering {
                Button(action: onClear) {
                    HStack(spacing: VegaDesign.Spacing.xs) {
                        Image(systemName: "arrow.down")
                            .font(VegaDesign.Font.caption)
                        Text("Clear")
                            .font(VegaDesign.Font.caption)
                    }
                    .foregroundStyle(isClearHovered ? .primary : .tertiary)
                    .padding(.horizontal, VegaDesign.Spacing.xs)
                }
                .buttonStyle(PlainButtonStyle())
                .help("Clear all regular tabs")
                .transition(.blur.animation(VegaDesign.Motion.quick))
                .onHoverTracking { state in
                    isClearHovered = state
                }
            }
        }
        .frame(height: VegaDesign.Size.rowGlyph + VegaDesign.Spacing.xxs)
        .frame(maxWidth: .infinity)
    }
}
 
