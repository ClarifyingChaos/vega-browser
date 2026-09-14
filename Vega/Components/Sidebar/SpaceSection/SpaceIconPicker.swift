//
//  SpaceIconPicker.swift
//  Vega
//
//  Curated SF Symbol grid shown in a popover. Replaces the emoji picker.
//

import SwiftUI

struct SpaceIconPicker: View {
    let selected: String
    let onPick: (String) -> Void

    static let symbols: [String] = [
        "square.grid.2x2", "briefcase", "house", "star", "book", "cart", "gamecontroller", "music.note",
        "film", "graduationcap", "heart", "leaf", "flame", "bolt", "globe", "chevron.left.forwardslash.chevron.right",
        "terminal", "hammer", "wrench.and.screwdriver", "paintbrush", "camera", "photo", "map", "airplane",
        "car", "building.2", "person", "person.2", "envelope", "message", "phone", "calendar",
        "clock", "folder", "tray", "doc", "note.text", "chart.bar", "dollarsign.circle", "creditcard",
        "tag", "bookmark", "flag", "mappin", "bell", "gearshape", "sparkles", "eye",
    ]

    private let columns = Array(repeating: GridItem(.fixed(VegaDesign.Size.iconButton), spacing: VegaDesign.Spacing.xs), count: 8)

    var body: some View {
        LazyVGrid(columns: columns, spacing: VegaDesign.Spacing.xs) {
            ForEach(Self.symbols, id: \.self) { symbol in
                Button {
                    onPick(symbol)
                } label: {
                    Image(systemName: symbol)
                        .font(VegaDesign.Font.title)
                        .foregroundStyle(symbol == selected ? Color.accentColor : .primary)
                        .frame(width: VegaDesign.Size.iconButton, height: VegaDesign.Size.iconButton)
                        .background(
                            VegaDesign.Radius.shape(VegaDesign.Radius.sm)
                                .fill(symbol == selected ? VegaDesign.Surface.fillPressed : .clear)
                        )
                }
                .buttonStyle(.plain)
                .help(symbol)
            }
        }
        .padding(VegaDesign.Spacing.lg)
    }
}
