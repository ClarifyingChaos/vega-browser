// Licensed under GPL-3.0. See LICENSE.
//
//  Updates.swift
//  Nook
//
//  FORK: Settings > Updates: the version you run, automatic updates, Check for Updates, and what
//  changed in every version (from VEGA_CHANGELOG.md, bundled as ChangelogData.swift).
//

import NookDesign
import NookUI
import NookWeb
import Sparkle
import SwiftUI

/// One version's section of the changelog.
struct ChangelogRelease: Identifiable {
    let id: String
    let title: String
    let date: String?
    let intro: String
    let groups: [(heading: String, items: [String])]

    /// "## Vega 1.6.0 (2026-11-13)" then an optional intro line, then "### Heading" groups of "- " bullets.
    static func parse(_ markdown: String) -> [ChangelogRelease] {
        var releases: [ChangelogRelease] = []
        var title = "", date: String?, intro: [String] = [], groups: [(String, [String])] = [], inRelease = false
        func flush() {
            guard inRelease else { return }
            releases.append(ChangelogRelease(id: title, title: title, date: date, intro: intro.joined(separator: " "), groups: groups.map { (heading: $0.0, items: $0.1) }))
        }
        for line in markdown.split(separator: "\n", omittingEmptySubsequences: false).map(String.init) {
            if line.hasPrefix("## ") {
                flush()
                inRelease = true; intro = []; groups = []
                let head = String(line.dropFirst(3))
                if let open = head.lastIndex(of: "("), head.hasSuffix(")") {
                    title = head[..<open].trimmingCharacters(in: .whitespaces)
                    date = String(head[head.index(after: open)..<head.index(before: head.endIndex)])
                } else { title = head; date = nil }
            } else if !inRelease {
                continue
            } else if line.hasPrefix("### ") {
                groups.append((String(line.dropFirst(4)), []))
            } else if line.hasPrefix("- ") {
                if groups.isEmpty { groups.append(("Changes", [])) }
                groups[groups.count - 1].1.append(String(line.dropFirst(2)))
            } else if !line.trimmingCharacters(in: .whitespaces).isEmpty, groups.isEmpty {
                intro.append(line.trimmingCharacters(in: .whitespaces))
            }
        }
        flush()
        return releases
    }
}

struct UpdatesSettingsView: View {
    @EnvironmentObject var browserManager: BrowserManager
    @State private var automatic = true
    @State private var checking = false
    @State private var beta = UserDefaults.standard.bool(forKey: AppDelegate.betaKey)
    @State private var crashReports = UserDefaults.standard.bool(forKey: CrashReporter.optInKey)
    private let releases = ChangelogRelease.parse(vegaChangelogMarkdown)

    private var version: String { Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?" }
    private var build: String { Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?" }
    private var updater: SPUUpdater? { browserManager.appDelegate?.updaterController.updater }

    var body: some View {
        Form {
            SettingsHero(symbol: "arrow.down.circle", title: "Updates", detail: "Vega keeps itself up to date. Every version's changes are listed below.", logotype: "vega-logotype")

            Section {
                LabeledContent("Version", value: "Vega \(version) (\(build))")
                if let update = browserManager.updateAvailability {
                    HStack {
                        VStack(alignment: .leading, spacing: NookDesign.Spacing.xxs) {
                            Text("Vega \(update.shortVersion) is \(update.isDownloaded ? "ready" : "available")")
                            Text(update.isDownloaded ? "Restart Vega to finish updating." : "Downloading…")
                                .font(NookDesign.Font.secondary)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if update.isDownloaded {
                            Button("Restart and Update") { browserManager.installPendingUpdateIfAvailable() }
                                .buttonStyle(.borderedProminent)
                        }
                    }
                } else {
                    HStack {
                        Text(checking ? "Checking…" : "Vega is up to date")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("Check for Updates") {
                            checking = true
                            updater?.checkForUpdatesInBackground()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 4) { checking = false }
                        }
                        .disabled(checking)
                    }
                }
            }

            Section {
                Toggle("Install updates automatically", isOn: Binding(
                    get: { automatic },
                    set: { on in
                        automatic = on
                        updater?.automaticallyChecksForUpdates = on
                        updater?.automaticallyDownloadsUpdates = on
                    }
                ))
            } footer: {
                Text("Vega checks every hour, downloads a new version in the background and tells you in the sidebar. It installs when you restart.")
            }

            Section {
                Toggle(isOn: Binding(
                    get: { beta },
                    set: { on in
                        beta = on
                        UserDefaults.standard.set(on, forKey: AppDelegate.betaKey)
                        // Next check looks at the beta channel too.
                        updater?.resetUpdateCycle()
                    }
                )) {
                    VStack(alignment: .leading, spacing: NookDesign.Spacing.xxs) {
                        Text("Get beta updates")
                        Text("Try new features a little early. A beta can have rough edges; turn this off to go back to the next regular release.")
                            .font(NookDesign.Font.secondary).foregroundStyle(.secondary)
                    }
                }
                Toggle(isOn: Binding(
                    get: { crashReports },
                    set: { on in crashReports = on; UserDefaults.standard.set(on, forKey: CrashReporter.optInKey) }
                )) {
                    VStack(alignment: .leading, spacing: NookDesign.Spacing.xxs) {
                        Text("Offer to send crash reports")
                        Text("After a crash, Vega offers a short report (version, macOS, where it crashed: no pages, passwords or history) that you read and send yourself.")
                            .font(NookDesign.Font.secondary).foregroundStyle(.secondary)
                    }
                }
            }

            ForEach(Array(releases.enumerated()), id: \.element.id) { index, release in
                Section {
                    if !release.intro.isEmpty {
                        Text(release.intro).foregroundStyle(.secondary)
                    }
                    ForEach(release.groups, id: \.heading) { group in
                        DisclosureGroup(group.heading, isExpanded: expansion(index, group.heading)) {
                            VStack(alignment: .leading, spacing: NookDesign.Spacing.md) {
                                ForEach(group.items, id: \.self) { item in
                                    Text(markdown(item))
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                            .padding(.vertical, NookDesign.Spacing.sm)
                        }
                    }
                } header: {
                    HStack {
                        Text(release.title)
                        Spacer()
                        if let date = release.date { Text(date).foregroundStyle(.secondary) }
                    }
                } footer: {
                    if index == releases.count - 1 {
                        Text("Changes from Nook, which Vega is built on, are in [Nook's releases](https://github.com/nook-browser/Nook/releases).")
                    }
                }
            }
        }
        .formStyle(.grouped)
        .onAppear { automatic = updater?.automaticallyDownloadsUpdates ?? true }
    }

    /// The newest version opens with its groups expanded; older ones stay folded.
    @State private var opened: Set<String> = []
    private func expansion(_ release: Int, _ heading: String) -> Binding<Bool> {
        let key = "\(release)|\(heading)"
        return Binding(get: { release == 0 || opened.contains(key) },
                       set: { if $0 { opened.insert(key) } else { opened.remove(key) } })
    }

    private func markdown(_ text: String) -> AttributedString {
        (try? AttributedString(markdown: text, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace))) ?? AttributedString(text)
    }
}
