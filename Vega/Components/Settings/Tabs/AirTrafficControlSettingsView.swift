//
//  AirTrafficControlSettingsView.swift
//  Vega
//

import VegaTabsCore
import SwiftUI

struct AirTrafficControlSettingsView: View {
    @Environment(\.vegaSettings) var vegaSettings
    @EnvironmentObject var browserManager: BrowserManager

    @State private var showingAddSheet = false
    @State private var editingRule: SiteRoutingRule?

    var body: some View {
        Form {
            Section {
                if vegaSettings.siteRoutingRules.isEmpty {
                    Text("No routing rules configured.")
                        .foregroundStyle(.tertiary)
                } else {
                    ForEach(vegaSettings.siteRoutingRules) { rule in
                        ruleRow(rule)
                    }
                    .onDelete(perform: deleteRules)
                }
            } header: {
                Text("Rules")
            } footer: {
                Text("Automatically route websites to specific spaces. When you navigate to a matching domain, a new tab opens in the designated space.")
            }

            Section {
                HStack {
                    Button {
                        showingAddSheet = true
                    } label: {
                        Label("Add Rule", systemImage: "plus")
                    }
                    Spacer()
                }
            }
        }
        .formStyle(.grouped)
        .sheet(isPresented: $showingAddSheet) {
            RuleEditSheet(
                browserManager: browserManager,
                onSave: { rule in
                    browserManager.siteRoutingManager.addRule(rule)
                }
            )
        }
        .sheet(item: $editingRule) { rule in
            RuleEditSheet(
                browserManager: browserManager,
                existingRule: rule,
                onSave: { updated in
                    browserManager.siteRoutingManager.updateRule(updated)
                }
            )
        }
    }

    private func ruleRow(_ rule: SiteRoutingRule) -> some View {
        let space = browserManager.tabs.space(rule.targetSpaceId)

        return LabeledContent {
            Toggle("Enabled", isOn: Binding(
                get: { rule.isEnabled },
                set: { newValue in
                    var updated = rule
                    updated.isEnabled = newValue
                    browserManager.siteRoutingManager.updateRule(updated)
                }
            ))
            .toggleStyle(.switch)
            .labelsHidden()
        } label: {
            VStack(alignment: .leading, spacing: VegaDesign.Spacing.xxs) {
                HStack(spacing: VegaDesign.Spacing.xs) {
                    Text(rule.domain)
                    if let pp = rule.pathPrefix, !pp.isEmpty {
                        Text(pp)
                            .foregroundStyle(.secondary)
                    }
                }
                HStack(spacing: VegaDesign.Spacing.xs) {
                    if let space {
                        Image(systemName: space.icon)
                            .font(VegaDesign.Font.caption)
                        Text(space.name)
                            .font(VegaDesign.Font.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Space deleted")
                            .font(VegaDesign.Font.caption)
                            .foregroundStyle(.red)
                    }
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            editingRule = rule
        }
    }

    private func deleteRules(at offsets: IndexSet) {
        for index in offsets {
            let rule = vegaSettings.siteRoutingRules[index]
            browserManager.siteRoutingManager.deleteRule(id: rule.id)
        }
    }
}

// MARK: - Add/Edit Sheet

private struct RuleEditSheet: View {
    let browserManager: BrowserManager
    var existingRule: SiteRoutingRule?
    let onSave: (SiteRoutingRule) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.vegaSettings) var vegaSettings

    @State private var domain: String = ""
    @State private var pathPrefix: String = ""
    @State private var selectedSpaceId: UUID?
    @State private var isEnabled: Bool = true
    @State private var validationError: String?

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section("Website") {
                    TextField("Domain (e.g. github.com)", text: $domain)
                        .textFieldStyle(.roundedBorder)
                    TextField("Path prefix (optional, e.g. /myorg)", text: $pathPrefix)
                        .textFieldStyle(.roundedBorder)
                }

                Section("Destination") {
                    Picker("Space", selection: $selectedSpaceId) {
                        Text("Select a space").tag(nil as UUID?)
                        ForEach(browserManager.tabs.orderedSpaces) { space in
                            Text(space.name)
                                .tag(space.id as UUID?)
                        }
                    }
                }

                Section {
                    Toggle("Enabled", isOn: $isEnabled)
                }

                if let error = validationError {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                            .font(VegaDesign.Font.caption)
                    }
                }
            }
            .formStyle(.grouped)

            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button(existingRule != nil ? "Save" : "Add Rule") { save() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(domain.trimmingCharacters(in: .whitespaces).isEmpty || selectedSpaceId == nil)
            }
            .padding(VegaDesign.Spacing.xl)
        }
        .frame(
            width: VegaDesign.Size.sheetSmallWidth,
            height: VegaDesign.Size.sheetSmallHeight
        )
        .onAppear {
            if let rule = existingRule {
                domain = rule.domain
                pathPrefix = rule.pathPrefix ?? ""
                selectedSpaceId = rule.targetSpaceId
                isEnabled = rule.isEnabled
            }
        }
    }

    private func save() {
        let normalized = SiteRoutingRule.normalizeDomain(domain)
        guard !normalized.isEmpty else {
            validationError = "Domain is required."
            return
        }

        let pp = pathPrefix.trimmingCharacters(in: .whitespaces)
        let effectivePathPrefix: String? = pp.isEmpty ? nil : pp

        let isDuplicate = vegaSettings.siteRoutingRules.contains { existing in
            existing.id != existingRule?.id &&
            existing.domain == normalized &&
            existing.pathPrefix == effectivePathPrefix
        }
        if isDuplicate {
            validationError = "A rule for this domain and path already exists."
            return
        }

        guard let spaceId = selectedSpaceId else {
            validationError = "Please select a target space."
            return
        }

        let rule = SiteRoutingRule(
            id: existingRule?.id ?? UUID(),
            domain: normalized,
            pathPrefix: effectivePathPrefix,
            targetSpaceId: spaceId,
            isEnabled: isEnabled
        )
        onSave(rule)
        dismiss()
    }
}
