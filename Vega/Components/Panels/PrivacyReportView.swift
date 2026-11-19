// Licensed under GPL-3.0. See LICENSE.
//
//  PrivacyReportView.swift
//  Vega
//
//  FORK: Safari-style Privacy Report: what Vega's blocker stopped, per site, and the protections that are on.
//

import SwiftUI
import VegaDesign
import VegaWeb

struct PrivacyReportView: View {
    @EnvironmentObject private var browserManager: BrowserManager
    @State private var stats = PrivacyStats.shared
    @State private var confirmingReset = false

    var body: some View {
        let settings = browserManager.vegaSettings
        Form {
            Section {
                HStack(spacing: VegaDesign.Spacing.xxl) {
                    stat(stats.totalBlocked, stats.totalBlocked == 1 ? "tracker or ad blocked" : "trackers and ads blocked")
                    stat(stats.sites.count, stats.sites.count == 1 ? "site" : "sites")
                    stat(stats.totalUpgraded, "made secure (HTTPS)")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, VegaDesign.Spacing.md)
            } footer: {
                Text("Since \(stats.since.formatted(date: .abbreviated, time: .omitted)). Counted on this Mac only; private windows are never counted.")
            }

            Section("Protections") {
                protection("Ad and tracker blocking", on: settings?.adBlockerEnabled ?? false)
                protection("HTTPS-Only Mode", on: settings?.warnBeforeHTTP ?? false)
                protection("Pop-up guard", on: settings?.blockScriptedPopups ?? false)
                protection("Relay-only WebRTC (hides your local IP)", on: settings?.webRTCRelayOnly ?? false)
                protection("Clear website data when Vega quits", on: settings?.clearDataOnQuit ?? false)
                Button("Privacy Settings…") { browserManager.openSettings(tab: .privacy) }
            }

            if !stats.topBlockedHosts().isEmpty {
                Section {
                    ForEach(stats.topBlockedHosts(), id: \.host) { entry in
                        LabeledContent(entry.host) { Text(entry.count.formatted()).monospacedDigit() }
                    }
                } header: {
                    Text("Trackers Blocked")
                } footer: {
                    Text("The addresses that tried to load most often.")
                }
            }

            Section {
                if stats.sites.isEmpty {
                    Text("Nothing blocked yet. Browse a little and come back.").foregroundStyle(.secondary)
                }
                ForEach(stats.topSites(), id: \.host) { entry in
                    LabeledContent(entry.host) {
                        Text("\(entry.site.blocked.formatted()) blocked" + (entry.site.upgraded > 0 ? " · \(entry.site.upgraded) secured" : ""))
                            .monospacedDigit().foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text("On These Sites")
            } footer: {
                Text("The pages you were on when they were blocked.")
            }

            Section {
                Button("Reset Report…", role: .destructive) { confirmingReset = true }
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 460, minHeight: 420)
        .confirmationDialog("Reset the Privacy Report?", isPresented: $confirmingReset) {
            Button("Reset", role: .destructive) { stats.reset() }
            Button("Cancel", role: .cancel) {}
        } message: { Text("The counts start again from zero. Your settings don't change.") }
    }

    private func stat(_ value: Int, _ label: String) -> some View {
        VStack(spacing: VegaDesign.Spacing.xxs) {
            Text(value.formatted()).font(VegaDesign.Font.display).monospacedDigit()
            Text(label).font(VegaDesign.Font.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    private func protection(_ title: String, on: Bool) -> some View {
        LabeledContent(title) {
            Label(on ? "On" : "Off", systemImage: on ? "checkmark.shield.fill" : "shield.slash")
                .foregroundStyle(on ? .green : .secondary)
        }
    }
}
