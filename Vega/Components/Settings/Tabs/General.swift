//
//  General.swift
//  Vega
//
//  Created by Maciek Bagiński on 07/12/2025.
//

import SwiftUI

struct SettingsGeneralTab: View {
    @EnvironmentObject var browserManager: BrowserManager
    @EnvironmentObject var tabManager: TabManager
    @Environment(\.vegaSettings) var vegaSettings
    @State private var showingAddSite = false
    @State private var showingAddEngine = false
    @State private var showingAdBlockerInfo = false

    var body: some View {
        @Bindable var settings = vegaSettings
        HStack(alignment: .top) {
            MemberCard()
            Form {
                Toggle("Warn before quitting Vega", isOn: $settings.askBeforeQuit)
                Toggle("Automatically update Vega", isOn: .constant(true))
                    .disabled(true)
                Toggle(isOn: $settings.adBlockerEnabled) {
                    HStack(spacing: 4) {
                        Text("Vega's Ad Blocker")
                        Button {
                            showingAdBlockerInfo.toggle()
                        } label: {
                            Image(systemName: "info.circle")
                                .font(.caption)
                                .foregroundStyle(.secondary.opacity(0.6))
                        }
                        .buttonStyle(.plain)
                        .popover(isPresented: $showingAdBlockerInfo, arrowEdge: .trailing) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Vega's Ad Blocker")
                                    .font(.headline)
                                Text("Built on uBlock Origin's community-maintained filter lists, adapted for WebKit. Blocks ads, trackers, and annoyances using network-level filtering, cosmetic hiding, and scriptlet injection — including YouTube ad blocking.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text("Filter lists update automatically every 24 hours.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(12)
                            .frame(width: 280)
                        }
                    }
                }
                .onChange(of: vegaSettings.adBlockerEnabled) { _, enabled in
                    browserManager.contentBlockerManager.setEnabled(enabled)
                }

                Section(header: Text("Search")) {
                    HStack {
                        Picker(
                            "Default search engine",
                            selection: $settings.searchEngineId
                        ) {
                            ForEach(SearchProvider.allCases) { provider in
                                Text(provider.displayName).tag(provider.rawValue)
                            }
                            ForEach(vegaSettings.customSearchEngines) { engine in
                                Text(engine.name).tag(engine.id.uuidString)
                            }
                        }

                        Button {
                            showingAddEngine = true
                        } label: {
                            Image(systemName: "plus")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }

                    // Show remove button for custom engines that are currently selected
                    if let selected = vegaSettings.customSearchEngines.first(where: { $0.id.uuidString == vegaSettings.searchEngineId }) {
                        HStack {
                            Text(selected.name)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Button("Remove") {
                                vegaSettings.customSearchEngines.removeAll { $0.id == selected.id }
                                vegaSettings.searchEngineId = SearchProvider.google.rawValue
                            }
                            .font(.caption)
                            .foregroundStyle(.red)
                            .buttonStyle(.plain)
                        }
                    }
                }

                Section("Performance") {
                    Picker("Tab Management", selection: Binding(
                        get: { vegaSettings.tabManagementMode },
                        set: { vegaSettings.tabManagementMode = $0 }
                    )) {
                        ForEach(TabManagementMode.allCases) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }

                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: vegaSettings.tabManagementMode.icon)
                            .foregroundStyle(.secondary)
                            .frame(width: 16)
                        Text(vegaSettings.tabManagementMode.description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Picker("On Startup", selection: Binding(
                        get: { vegaSettings.startupLoadMode },
                        set: { vegaSettings.startupLoadMode = $0 }
                    )) {
                        ForEach(StartupLoadMode.allCases) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }

                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "power")
                            .foregroundStyle(.secondary)
                            .frame(width: 16)
                        Text(vegaSettings.startupLoadMode.description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Button("Unload All Inactive Tabs") {
                        tabManager.unloadAllInactiveTabs()
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
        .sheet(isPresented: $showingAddEngine) {
            CustomSearchEngineEditor { newEngine in
                vegaSettings.customSearchEngines.append(newEngine)
            }
        }
    }
}

// MARK: - Custom Search Engine Editor

struct CustomSearchEngineEditor: View {
    let onSave: (CustomSearchEngine) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var urlTemplate: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Add Custom Search Engine")
                .font(.headline)

            Form {
                TextField("Name (e.g. Startpage)", text: $name)
                TextField("URL Template (use %@ for query)", text: $urlTemplate)
            }
            .formStyle(.grouped)

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .buttonStyle(.bordered)
                Button("Save") {
                    let engine = CustomSearchEngine(
                        name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                        urlTemplate: urlTemplate.trimmingCharacters(in: .whitespacesAndNewlines)
                    )
                    onSave(engine)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(name.isEmpty || urlTemplate.isEmpty)
            }
        }
        .padding(20)
        .frame(width: 450)
    }
}
