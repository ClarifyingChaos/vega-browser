//
//  SettingsTabBar.swift
//  Vega
//
//  Created by Maciek Bagiński on 03/08/2025.
//
import SwiftUI

struct SettingsTabBar: View {
    @EnvironmentObject var browserManager: BrowserManager
    @Environment(\.vegaSettings) var vegaSettings

    var body: some View {
        ZStack {
            BlurEffectView(
                material: vegaSettings.currentMaterial,
                state: .active
            )
            HStack {
                Spacer()
                Text(vegaSettings.currentSettingsTab.name)
                    .font(.headline)
                Spacer()
            }

        }
        .backgroundDraggable()
    }
}
