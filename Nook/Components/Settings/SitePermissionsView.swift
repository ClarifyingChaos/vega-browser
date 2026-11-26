// Licensed under GPL-3.0. See LICENSE.
//
//  SitePermissionsView.swift
//  Nook
//
//  FORK: every site with a setting of its own, in one place (Settings › Privacy › Site Permissions): camera and
//  microphone answers, JavaScript, the mobile site, automatic Picture in Picture and ad blocking. Site Controls changes
//  the site in front; this is where they can all be seen and undone: a searchable list, then one page per site.
//

import SwiftUI
import NookDesign
import NookSettings
import NookUI

struct SitePermissionsView: View {
    @Environment(\.nookSettings) private var settings
    @State private var prefs = SitePreferences.shared
    @State private var query = ""
    /// The site whose page is showing; nil is the list.
    @State private var selected: String?
    @State private var confirmingResetAll = false

    private var allHosts: Set<String> {
        Set(settings.sitePermissions.keys)
            .union(prefs.sites.keys)
            .union(settings.adBlockerWhitelist.map { SitePermissionRecord.key(for: $0) })
    }

    private var matches: [String] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        return allHosts.filter { q.isEmpty || $0.contains(q) }.sorted()
    }

    var body: some View {
        Form {
            if let selected { detail(selected) } else { list }
        }
        .formStyle(.grouped)
        .navigationTitle("Site Permissions")
        .confirmationDialog("Reset every site\u{2019}s settings?", isPresented: $confirmingResetAll) {
            Button("Reset All", role: .destructive) { allHosts.forEach(reset) }
        } message: {
            Text("Camera and microphone answers, content settings and ad blocking exceptions go back to Vega\u{2019}s defaults.")
        }
    }

    // MARK: - List

    @ViewBuilder private var list: some View {
        if allHosts.isEmpty {
            Section {
                VStack(spacing: NookDesign.Spacing.md) {
                    NookSymbol("shield.lefthalf.filled", size: 34).foregroundStyle(.secondary)
                    Text("No custom site settings").fontWeight(.semibold)
                    Text("Press \u{21E7}\u{2318}E on any site to change what it may do.")
                        .font(NookDesign.Font.caption).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, NookDesign.Spacing.xxl)
                .accessibilityElement(children: .combine)
            } footer: {
                Text("Sites use Vega\u{2019}s defaults and ask before using your camera or microphone.")
            }
        } else {
            Section {
                TextField("Search sites", text: $query, prompt: Text("Search sites"))
                    .textFieldStyle(.roundedBorder).labelsHidden()
                if matches.isEmpty { Text("No sites match.").foregroundStyle(.secondary) }
                ForEach(matches, id: \.self) { host in
                    Button { selected = host } label: {
                        HStack(spacing: NookDesign.Spacing.lg) {
                            icon("globe")
                            VStack(alignment: .leading, spacing: NookDesign.Spacing.xxs) {
                                Text(host)
                                Text(summary(host)).font(NookDesign.Font.caption).foregroundStyle(.secondary).lineLimit(1)
                            }
                            Spacer()
                            NookSymbol("chevron.right", size: 16).foregroundStyle(.secondary)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityElement(children: .combine)
                    .accessibilityAddTraits(.isButton)
                }
            } footer: {
                Text("Sites not listed use Vega\u{2019}s defaults and ask before using your camera or microphone.")
            }
            Section {
                Button("Reset All\u{2026}", nookIcon: "trash", role: .destructive) { confirmingResetAll = true }
            }
        }
    }

    // MARK: - One Site

    @ViewBuilder private func detail(_ host: String) -> some View {
        Section {
            HStack(spacing: NookDesign.Spacing.lg) {
                Button("All Sites", nookIcon: "chevron.left") { selected = nil }
                Text(host).font(NookDesign.Font.heading).lineLimit(1)
                Spacer()
            }
        }
        Section("Permissions") {
            permissionRow("Camera", "camera", .camera, host)
            permissionRow("Microphone", "mic.fill", .microphone, host)
            triRow("Pop-ups", "arrow.up.forward.app", value: prefs.prefs(for: host).allowsPopups, on: "Allow", off: "Block") { v in
                prefs.update(host) { $0.allowsPopups = v }
            }
        }
        Section("Content") {
            row("Block ads and trackers", "shield.lefthalf.filled",
                selection: Binding(get: { !isAllowListed(host) }, set: { block in
                    settings.adBlockerWhitelist.removeAll { SitePermissionRecord.key(for: $0) == host }
                    if !block { settings.adBlockerWhitelist.append(host) }
                })) {
                Text("On").tag(true)
                Text("Off").tag(false)
            }
            row("Auto-play", "video.fill", note: "Applies from the next page load",
                selection: Binding(get: { prefs.prefs(for: host).autoplay ?? .allowAll },
                                   set: { v in prefs.update(host) { $0.autoplay = v == .allowAll ? nil : v } })) {
                Text("Allow").tag(SiteAutoplay.allowAll)
                Text("No sound").tag(SiteAutoplay.stopMediaWithSound)
                Text("Never").tag(SiteAutoplay.never)
            }
            triRow("Keep video in sidebar", "pip", value: prefs.prefs(for: host).autoPiP, on: "On", off: "Off") { v in
                prefs.update(host) { $0.autoPiP = v }
            }
            triRow("JavaScript", "arrow.clockwise", value: prefs.prefs(for: host).javaScript, on: "On", off: "Off") { v in
                prefs.update(host) { $0.javaScript = v }
            }
            triRow("Website version", "globe", value: prefs.prefs(for: host).mobileSite, on: "Mobile", off: "Desktop") { v in
                prefs.update(host) { $0.mobileSite = v }
            }
        }
        Section {
            Button("Reset This Site", nookIcon: "trash", role: .destructive) {
                reset(host)
                selected = nil
            }
        }
    }

    private func icon(_ symbol: String) -> some View {
        NookSymbol(symbol, size: 18).frame(width: 22).foregroundStyle(.secondary).accessibilityHidden(true)
    }

    private func row<Value: Hashable, Choices: View>(_ title: String, _ symbol: String, note: String? = nil,
                                                    selection: Binding<Value>, @ViewBuilder choices: () -> Choices) -> some View {
        HStack(spacing: NookDesign.Spacing.lg) {
            icon(symbol)
            VStack(alignment: .leading, spacing: NookDesign.Spacing.xxs) {
                Text(title)
                if let note { Text(note).font(NookDesign.Font.caption).foregroundStyle(.secondary) }
            }
            Spacer()
            Picker(title, selection: selection, content: choices)
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()
        }
    }

    private func permissionRow(_ title: String, _ symbol: String, _ permission: SitePermission, _ host: String) -> some View {
        row(title, symbol, selection: Binding(get: { settings.permission(permission, for: host) },
                                              set: { settings.setPermission(permission, to: $0, for: host) })) {
            ForEach(SitePermissionPolicy.allCases, id: \.self) { Text($0.label).tag($0) }
        }
    }

    /// Default / on / off for a value that is nil when the site uses Vega's default.
    private func triRow(_ title: String, _ symbol: String, value: Bool?, on: String, off: String, set: @escaping (Bool?) -> Void) -> some View {
        row(title, symbol, selection: Binding(get: { value.map { $0 ? 1 : 0 } ?? -1 }, set: { set($0 < 0 ? nil : $0 == 1) })) {
            Text("Default").tag(-1)
            Text(on).tag(1)
            Text(off).tag(0)
        }
    }

    private func isAllowListed(_ host: String) -> Bool {
        settings.adBlockerWhitelist.contains { SitePermissionRecord.key(for: $0) == host }
    }

    private func summary(_ host: String) -> String {
        var parts: [String] = []
        for p in SitePermission.allCases {
            let policy = settings.permission(p, for: host)
            if policy != .ask { parts.append("\(p.rawValue.capitalized): \(policy.label)") }
        }
        let site = prefs.prefs(for: host)
        if let js = site.javaScript { parts.append("JavaScript \(js ? "on" : "off")") }
        if let mobile = site.mobileSite { parts.append(mobile ? "Mobile site" : "Desktop site") }
        if let popups = site.allowsPopups { parts.append("Pop-ups \(popups ? "allowed" : "blocked")") }
        if let play = site.autoplay { parts.append(play.label) }
        if let pip = site.autoPiP { parts.append("PiP \(pip ? "on" : "off")") }
        if isAllowListed(host) { parts.append("Ads allowed") }
        return parts.joined(separator: " · ")
    }

    private func reset(_ host: String) {
        for p in SitePermission.allCases { settings.setPermission(p, to: .ask, for: host) }
        prefs.reset(host)
        settings.adBlockerWhitelist.removeAll { SitePermissionRecord.key(for: $0) == host }
    }
}
