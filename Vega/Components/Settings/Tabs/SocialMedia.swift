//
//  SocialMedia.swift
//  Vega
//
//  Created by Claude on 15/09/2026.
//

import SwiftUI

struct SettingsSocialMediaTab: View {
    @Environment(\.vegaSettings) var vegaSettings

    var body: some View {
        @Bindable var settings = vegaSettings
        Form {
            Section {
                Toggle("Image download button", isOn: $settings.socialImageDownload)
            } footer: {
                Text("Shows a download button on photos on Instagram, Facebook, and VSCO, and saves the largest size the page offers to Downloads. Applies when one of these pages next loads.")
            }
        }
        .formStyle(.grouped)
    }
}
