// Licensed under GPL-3.0. See LICENSE.
//
//  DevPanelColumn.swift
//  Vega
//
//  The right column. The AI chat alone while Developer Mode is off; with it on, tabs for the chat,
//  the Console and the Network log of the window's selected page.
//

import SwiftUI
import VegaDesign
import VegaWeb
import VegaUI
import VegaSettings

struct DevPanelColumn: View {
    @Environment(BrowserWindowState.self) private var windowState
    @EnvironmentObject var browserManager: BrowserManager
    @Environment(\.vegaSettings) var vegaSettings

    var body: some View {
        SidebarAIChat()
    }
}

/// Shown in place of a tab's content when the page has no capture yet.
struct DevPanelEmpty: View {
    var body: some View {
        Text("Reload the page to capture it.")
            .font(VegaDesign.Font.bodyRegular)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
