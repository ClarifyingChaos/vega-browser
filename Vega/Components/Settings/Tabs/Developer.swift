// Licensed under GPL-3.0. See LICENSE.
//
//  Developer.swift
//  Vega
//
//  Developer Mode and Browser Control.
//

import VegaSettings
import SwiftUI
import VegaUI
import VegaDesign

struct SettingsDeveloperTab: View {
    @Environment(\.vegaSettings) var vegaSettings
    @EnvironmentObject var browserManager: BrowserManager

    var body: some View {
        @Bindable var settings = vegaSettings
        Form {
            SettingsHero(symbol: "hammer", title: "Developer", detail: "Developer tools, and browser control for agents.")

            Section {
                Toggle("Developer Mode", isOn: $settings.developerModeEnabled)
                    .onChange(of: settings.developerModeEnabled) { _, on in
                        browserManager.tabs.setDeveloperMode(on)
                        DevMCPServer.shared.applyEnabledSetting(on && settings.browserControlServerEnabled)
                    }
            } footer: {
                Text("Shows developer tools and lets you turn on Browser Control.")
                    .font(VegaDesign.Font.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                Toggle(isOn: $settings.browserControlServerEnabled) {
                    VStack(alignment: .leading, spacing: VegaDesign.Spacing.xxs) {
                        Text("Allow agents to control this browser")
                            .font(VegaDesign.Font.body)
                        Text("Serves MCP on 127.0.0.1:47823 so a coding agent can drive Vega")
                            .font(VegaDesign.Font.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .disabled(!settings.developerModeEnabled)
                // The setting lives in VegaSettings, which cannot reach the server; start and
                // stop it from here so the toggle still takes effect without a relaunch.
                .onChange(of: settings.browserControlServerEnabled) {
                    DevMCPServer.shared.applyEnabledSetting($1 && settings.developerModeEnabled)
                }
            } header: {
                Text("Browser Control")
            } footer: {
                Text("A client must send the token from Application Support/com.vega.browser/dev-mcp-token. Any program on this Mac can read that file, and with it run JavaScript in your tabs and read pages you are signed in to. Leave this off unless you are driving Vega from an agent.")
                    .font(VegaDesign.Font.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}
