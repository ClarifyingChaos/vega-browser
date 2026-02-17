//
//  General.swift
//  Vega
//
//  Created by Maciek Bagiński on 07/12/2025.
//

import SwiftUI

struct SettingsGeneralTab: View {
    @Environment(\.vegaSettings) var vegaSettings
    @State private var showingAddSite = false

    var body: some View {
        @Bindable var settings = vegaSettings
        HStack(alignment: .top) {
            MemberCard()
            Form {
                Toggle("Warn before quitting Vega", isOn: $settings.askBeforeQuit)
                Toggle("Automatically update Vega", isOn: .constant(true))
                    .disabled(true)
                Toggle("Vega's Ad Blocker", isOn: .constant(false))
                    .disabled(true)

                Section(header: Text("Search")) {
                    Picker(
                        "Default search engine",
                        selection: $settings.searchEngine
                    ) {
                        ForEach(SearchProvider.allCases) { provider in
                            Text(provider.displayName).tag(provider)
                        }
                    }
                }

                Section {
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
                            Button {
                                vegaSettings.siteSearchEntries.removeAll { $0.id == entry.id }
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundStyle(.red)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    Button {
                        showingAddSite = true
                    } label: {
                        Label("Add Site", systemImage: "plus")
                    }

                    Button("Reset to Defaults") {
                        vegaSettings.siteSearchEntries = SiteSearchEntry.defaultSites
                    }
                } header: {
                    Text("Site Search")
                } footer: {
                    Text("Type a prefix in the command palette and press Tab to search a site directly.")
                }
            }
            .formStyle(.grouped)
        }
        .sheet(isPresented: $showingAddSite) {
            SiteSearchEntryEditor(entry: nil) { newEntry in
                vegaSettings.siteSearchEntries.append(newEntry)
            }
        }
    }
}
