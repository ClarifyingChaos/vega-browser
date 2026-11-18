// Licensed under GPL-3.0. See LICENSE.
//
//  SitePermissionsView.swift
//  Vega
//
//  FORK: every site with a setting of its own, in one place (Settings › Privacy › Site Permissions): camera and
//  microphone answers, JavaScript, the mobile site, automatic Picture in Picture and ad blocking. Site Controls changes
//  the site in front; this is where they can all be seen and undone.
//

import SwiftUI
import VegaDesign
import VegaSettings

struct SitePermissionsView: View {
    @Environment(\.vegaSettings) private var settings
    @State private var prefs = SitePreferences.shared
    @State private var query = ""

    private var hosts: [String] {
        let all = Set(settings.sitePermissions.keys)
            .union(prefs.sites.keys)
            .union(settings.adBlockerWhitelist.map { SitePermissionRecord.key(for: $0) })
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        return all.filter { q.isEmpty || $0.contains(q) }.sorted()
    }

    var body: some View {
        Form {
            Section {
                if hosts.isEmpty {
                    Text(query.isEmpty ? "No site has a setting of its own yet. Use Site Controls (⇧⌘E) on a site to change one." : "No sites match.")
                        .foregroundStyle(.secondary)
                }
                ForEach(hosts, id: \.self) { host in
                    DisclosureGroup {
                        permissionPicker("Camera", .camera, host)
                        permissionPicker("Microphone", .microphone, host)
                        triPicker("JavaScript", value: prefs.prefs(for: host).javaScript, on: "On", off: "Off") { v in prefs.update(host) { $0.javaScript = v } }
                        triPicker("Version", value: prefs.prefs(for: host).mobileSite, on: "Mobile", off: "Desktop") { v in prefs.update(host) { $0.mobileSite = v } }
                        triPicker("Picture in Picture on leaving", value: prefs.prefs(for: host).autoPiP, on: "On", off: "Off") { v in prefs.update(host) { $0.autoPiP = v } }
                        Toggle("Block ads and trackers", isOn: Binding(
                            get: { !isAllowListed(host) },
                            set: { block in
                                settings.adBlockerWhitelist.removeAll { SitePermissionRecord.key(for: $0) == host }
                                if !block { settings.adBlockerWhitelist.append(host) }
                            }))
                        Button("Reset \(host)", role: .destructive) { reset(host) }
                    } label: {
                        VStack(alignment: .leading, spacing: VegaDesign.Spacing.xxs) {
                            Text(host)
                            Text(summary(host)).font(VegaDesign.Font.caption).foregroundStyle(.secondary).lineLimit(1)
                        }
                    }
                }
            } header: {
                TextField("Search sites", text: $query).textFieldStyle(.roundedBorder)
            } footer: {
                Text("A site not listed uses Vega's defaults, and asks before using your camera or microphone.")
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Site Permissions")
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
        if let pip = site.autoPiP { parts.append("PiP \(pip ? "on" : "off")") }
        if isAllowListed(host) { parts.append("Ads allowed") }
        return parts.joined(separator: " · ")
    }

    private func permissionPicker(_ title: String, _ permission: SitePermission, _ host: String) -> some View {
        Picker(title, selection: Binding(get: { settings.permission(permission, for: host) },
                                         set: { settings.setPermission(permission, to: $0, for: host) })) {
            ForEach(SitePermissionPolicy.allCases, id: \.self) { Text($0.label).tag($0) }
        }
    }

    /// Default / on / off for a value that is nil when the site uses Vega's default.
    private func triPicker(_ title: String, value: Bool?, on: String, off: String, set: @escaping (Bool?) -> Void) -> some View {
        Picker(title, selection: Binding(get: { value.map { $0 ? 1 : 0 } ?? -1 }, set: { set($0 < 0 ? nil : $0 == 1) })) {
            Text("Default").tag(-1)
            Text(on).tag(1)
            Text(off).tag(0)
        }
    }

    private func reset(_ host: String) {
        for p in SitePermission.allCases { settings.setPermission(p, to: .ask, for: host) }
        prefs.reset(host)
        settings.adBlockerWhitelist.removeAll { SitePermissionRecord.key(for: $0) == host }
    }
}
