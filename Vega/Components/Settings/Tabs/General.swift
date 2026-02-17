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

                Section(header: Text("Site Search")) {
                    ForEach(vegaSettings.siteSearchEntries) { entry in
                        HStack(spacing: 8) {
                            Circle()
                                .fill(entry.color)
                                .frame(width: 10, height: 10)
                            Text(entry.name)
                            Spacer()
                            Text(entry.domain)
                                .foregroundStyle(.secondary)
                                .font(.caption)
                        }
                    }
                    .onDelete { indexSet in
                        vegaSettings.siteSearchEntries.remove(atOffsets: indexSet)
                    }

                    Button("Reset to Defaults") {
                        vegaSettings.siteSearchEntries = SiteSearchEntry.defaultSites
                    }
                }
            }
            .formStyle(.grouped)
        }
    }
}
