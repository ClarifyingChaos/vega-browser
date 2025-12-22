//
//  General.swift
//  Vega
//
//  Created by Maciek Bagiński on 07/12/2025.
//

import SwiftUI

struct SettingsGeneralTab: View {
    @Environment(\.vegaSettings) var vegaSettings


    var body: some View {
        @Bindable var settings = vegaSettings
        HStack{
            MemberCard()
            Form {
                Toggle("Warn before quitting Vega",isOn: $settings.askBeforeQuit)
                Toggle("Automatically update Vega", isOn: .constant(true))
                    .disabled(true)
                Toggle("Vega's Ad Blocker", isOn: .constant(false))
                    .disabled(true)
                
                Section(header: Text("Search")) {
                    Picker(
                        "Default search engine",
                        selection: $settings
                            .searchEngine
                    ) {
                        ForEach(SearchProvider.allCases) { provider in
                            Text(provider.displayName).tag(provider)
                        }
                    }
                }
            }
            .formStyle(.grouped)
        }
    }
}
