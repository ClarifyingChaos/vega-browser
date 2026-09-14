//
//  Advanced.swift
//  Vega
//
//  Created by Maciek Bagiński on 03/08/2025.
//

import SwiftUI

struct AdvancedSettingsView: View {
    @EnvironmentObject var browserManager: BrowserManager
    @Environment(\.vegaSettings) var vegaSettings

    var body: some View {
        @Bindable var settings = vegaSettings
        Form {
            #if DEBUG
            Section {
                Toggle("Show Update Notification", isOn: $settings.debugToggleUpdateNotification)
            } header: {
                Text("Debug Options")
            } footer: {
                Text("Force display the sidebar update notification for appearance debugging.")
            }
            #endif
        }
        .formStyle(.grouped)
    }
}
