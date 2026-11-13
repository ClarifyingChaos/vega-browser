// Licensed under GPL-3.0. See LICENSE.
//
//  SettingsHero.swift
//  Vega
//
//  FORK: the card at the top of a macOS 27 System Settings pane: the pane's symbol in a rounded
//  tile, its name in bold, and one line on what it holds, centred. Each settings page opens with it.
//

import SwiftUI
import VegaDesign

public struct SettingsHero: View {
    let symbol: String
    let title: String
    let detail: String

    public init(symbol: String, title: String, detail: String) {
        self.symbol = symbol
        self.title = title
        self.detail = detail
    }

    public var body: some View {
        Section {
            VStack(spacing: VegaDesign.Spacing.sm) {
                Image(systemName: symbol)
                    .font(.system(size: 26, weight: .regular))
                    .foregroundStyle(.primary)
                    .frame(width: 48, height: 48)
                    .background(VegaDesign.Radius.shape(12).fill(.quaternary))
                    .overlay(VegaDesign.Radius.shape(12).strokeBorder(.separator, lineWidth: 0.5))
                    .accessibilityHidden(true)
                Text(title)
                    .font(.system(size: 22, weight: .bold))
                    .padding(.top, VegaDesign.Spacing.xxs)
                Text(detail)
                    .font(VegaDesign.Font.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, VegaDesign.Spacing.lg)
            .accessibilityElement(children: .combine)
        }
    }
}
