// Licensed under GPL-3.0. See LICENSE.
//
//  AdBlocker.swift
//  Vega
//
//  Created by Bain Gurley on 26/03/2026.
//

import SwiftUI

import VegaBlocker
import VegaDesign
import VegaSettings

public struct SettingsAdBlockerTab: View {
    @Environment(VegaSettingsService.self) var vegaSettings
    @Environment(\.contentBlocker) private var contentBlocker
    @State private var isUpdatingFilters = false

    public init() {}

    public var body: some View {
        @Bindable var settings = vegaSettings
        Form {
            Section {
                Toggle("Ad & Tracker Blocker", isOn: $settings.adBlockerEnabled)
                    .onChange(of: vegaSettings.adBlockerEnabled) { _, enabled in
                        contentBlocker?.setEnabled(enabled)
                    }
            } footer: {
                Text("Filter lists update automatically every 24 hours.")
            }

            if vegaSettings.adBlockerEnabled {
                Section("Status") {
                    HStack {
                        if isUpdatingFilters {
                            ProgressView()
                                .controlSize(.small)
                            Text("Updating filter lists...")
                                .foregroundStyle(.secondary)
                        } else {
                            if let lastUpdate = vegaSettings.adBlockerLastUpdate {
                                Text("Last updated: \(lastUpdate, style: .relative) ago")
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("Update Filters") {
                                isUpdatingFilters = true
                                Task {
                                    await contentBlocker?.recompileFilterLists()
                                    isUpdatingFilters = false
                                }
                            }
                        }
                    }
                }

                Section("Default Filter Lists") {
                    ForEach(FilterListManager.defaultLists, id: \.filename) { list in
                        LabeledContent {
                            Text(list.category.rawValue)
                                .font(VegaDesign.Font.caption)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, VegaDesign.Spacing.sm)
                                .padding(.vertical, VegaDesign.Spacing.xxs)
                                .background(VegaDesign.Surface.fill)
                                .clipShape(VegaDesign.Radius.shape(VegaDesign.Radius.xs))
                        } label: {
                            Label {
                                Text(list.name)
                            } icon: {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                            }
                        }
                    }
                }

                if !FilterListManager.optionalLists.isEmpty {
                    ForEach(FilterListManager.FilterListCategory.allCases, id: \.rawValue) { category in
                        let listsInCategory = FilterListManager.optionalLists.filter { $0.category == category }
                        if !listsInCategory.isEmpty {
                            Section(category.rawValue) {
                                ForEach(listsInCategory, id: \.filename) { list in
                                    Toggle(list.name, isOn: Binding(
                                        get: { vegaSettings.enabledOptionalFilterLists.contains(list.filename) },
                                        set: { enabled in
                                            if enabled {
                                                vegaSettings.enabledOptionalFilterLists.append(list.filename)
                                            } else {
                                                vegaSettings.enabledOptionalFilterLists.removeAll { $0 == list.filename }
                                            }
                                            contentBlocker?.filterListManager.enabledOptionalFilterListFilenames = Set(vegaSettings.enabledOptionalFilterLists)
                                            Task {
                                                await contentBlocker?.recompileFilterLists()
                                            }
                                        }
                                    ))
                                }
                            }
                        }
                    }

                    Section {
                        Text("Enabling additional lists improves blocking but increases memory usage.")
                            .font(VegaDesign.Font.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .formStyle(.grouped)
    }
}
