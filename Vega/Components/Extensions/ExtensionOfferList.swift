// Licensed under GPL-3.0. See LICENSE.
//
//  ExtensionOfferList.swift
//  Vega
//

import AppKit
import VegaDesign
import SwiftUI

struct ExtensionOfferList: View {
    let offers: [ExtensionOffer]
    @Binding var selected: Set<String>

    static func installTitle(count: Int) -> String {
        switch count {
        case 0: "Continue"
        case 1: "Install 1 extension"
        default: "Install \(count) extensions"
        }
    }

    var body: some View {
        ViewThatFits(in: .vertical) {
            rows
            ScrollView { rows }
        }
        .frame(maxHeight: 320)
    }

    private var rows: some View {
        VStack(alignment: .leading, spacing: VegaDesign.Spacing.md) {
            ForEach(offers) { offer in
                Toggle(isOn: isSelected(offer)) {
                    HStack(spacing: VegaDesign.Spacing.md) {
                        Group {
                            if let icon = offer.icon {
                                Image(nsImage: icon)
                                    .resizable()
                            } else {
                                Image(systemName: "puzzlepiece.extension")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .frame(width: 24, height: 24)

                        VStack(alignment: .leading, spacing: VegaDesign.Spacing.xxs) {
                            Text(offer.name)
                                .font(VegaDesign.Font.label)
                                .lineLimit(1)
                            Text(offer.version)
                                .font(VegaDesign.Font.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .toggleStyle(.checkbox)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func isSelected(_ offer: ExtensionOffer) -> Binding<Bool> {
        Binding(
            get: { selected.contains(offer.id) },
            set: { isOn in
                if isOn {
                    selected.insert(offer.id)
                } else {
                    selected.remove(offer.id)
                }
            }
        )
    }
}
