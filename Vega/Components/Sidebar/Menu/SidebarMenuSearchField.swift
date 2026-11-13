// Licensed under GPL-3.0. See LICENSE.
//
//  SidebarMenuSearchField.swift
//  Vega
//

import SwiftUI
import VegaDesign
import VegaUI

/// The history and downloads search field: a filled squircle the height of the sidebar's controls.
struct SidebarMenuSearchField: View {
    let prompt: LocalizedStringKey
    @Binding var text: String
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: VegaDesign.Spacing.sm) {
            VegaSymbol("magnifyingglass", size: 16)
                .font(VegaDesign.Font.body)
                .foregroundStyle(.secondary)
            TextField(prompt, text: $text)
                .textFieldStyle(.plain)
                .font(VegaDesign.Font.secondary)
                .foregroundStyle(.primary)
                .focused($isFocused)

            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(VegaDesign.Font.secondary)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, VegaDesign.Spacing.lg)
        .frame(height: VegaDesign.Size.chromeControl)
        .frame(maxWidth: .infinity)
        .contentShape(VegaDesign.Radius.shape(VegaDesign.Radius.md))
        .onTapGesture { isFocused = true }
        .vegaControlSurface(in: VegaDesign.Radius.shape(VegaDesign.Radius.md))
    }
}
