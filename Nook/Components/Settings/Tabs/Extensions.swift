// Licensed under GPL-3.0. See LICENSE.
//
//  Extensions.swift
//  Nook
//
//  Created by Maciek Bagiński on 03/08/2025.
//

import AppKit
import SwiftUI
import NookUI
import NookDesign
import NookWeb
import NookSettings

struct ExtensionsSettingsView: View {
    @EnvironmentObject var browserManager: BrowserManager
    @Environment(TabsController.self) private var tabs
    @ObservedObject var extensionManager: ExtensionManager
    /// The extension sets in use and the one shown, for the picker once there is more than one.
    var sets: [ExtensionSetChoice] = []
    var shownSet: Binding<UUID>?
    @State private var pendingRemoval: InstalledExtension?
    @State private var consent: PendingConsent?
    @State private var isScanningSafari = false

    var body: some View {
        Form {
            // FORK: Vega's page (mockup docs/mockups/extensions-settings.html, Layout A): the two ways to add an
            // extension under the title, profiles as a menu, then installed and Safari extensions.
            SettingsHero(symbol: "puzzlepiece.extension", title: "Extensions", detail: "Add, turn off or remove browser extensions.") {
                HStack(spacing: NookDesign.Spacing.md) {
                    Button("From a File…", nookIcon: "folder.badge.plus") {
                        extensionManager.showExtensionInstallDialog(presenter: presentConsent)
                    }
                    .buttonStyle(.borderedProminent)
                    .help("A folder, or a ZIP, CRX or XPI file")
                    Button("Chrome Web Store", nookIcon: "arrow.up.forward.app") {
                        openWebStore()
                    }
                    .buttonStyle(.bordered)
                    .help("Install from an extension's page in the store")
                }
                .controlSize(.large)
            }

            if sets.count > 1, let shownSet {
                Section {
                    Picker("Showing extensions for", selection: shownSet) {
                        ForEach(sets, id: \.set) { choice in
                            Text(choice.members.compactMap { id in tabs.profiles.first { $0.id == id }?.name }.joined(separator: ", "))
                                .tag(choice.set)
                        }
                    }
                    .pickerStyle(.menu)
                } header: {
                    Text("Profiles")
                } footer: {
                    Text("Synced profiles share extensions and their data. Set this for each profile in Settings › Spaces.")
                        .font(NookDesign.Font.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                if installed.isEmpty {
                    VStack(spacing: NookDesign.Spacing.xs) {
                        Text("No Extensions Installed")
                            .font(NookDesign.Font.title)
                        Text("Add one from a file or the Chrome Web Store.")
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, NookDesign.Spacing.lg)
                } else {
                    ForEach(installed, id: \.id) { ext in
                        ExtensionRowView(
                            extension: ext,
                            extensionManager: extensionManager,
                            hasOptionsPage: extensionManager.hasOptionsPage(ext.id),
                            update: extensionManager.safariUpdate(for: ext),
                            alternative: extensionManager.safariAlternative(to: ext),
                            onInstall: install,
                            onRemove: { pendingRemoval = ext }
                        )
                    }
                }
            } header: {
                HStack {
                    Text("Installed")
                    Spacer()
                    if !installed.isEmpty {
                        Text(installed.count == 1 ? "1 extension" : "\(installed.count) extensions")
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section {
                if isScanningSafari || extensionManager.safariExtensions == nil {
                    HStack(spacing: NookDesign.Spacing.md) {
                        ProgressView()
                            .controlSize(.small)
                        Text("Scanning…")
                            .foregroundStyle(.secondary)
                    }
                } else if extensionManager.uninstalledSafariExtensions.isEmpty {
                    Text("No Safari Web Extensions found on this Mac.")
                        .foregroundStyle(.secondary)
                }
                ForEach(extensionManager.uninstalledSafariExtensions) { ext in
                    SafariExtensionRowView(info: ext, onInstall: { install(ext) })
                }
            } header: {
                HStack {
                    Text("Safari Extensions")
                    Spacer()
                    Button("Scan Again") { scanSafari() }
                        .buttonStyle(.plain)
                        .foregroundStyle(.primary)
                        .disabled(isScanningSafari)
                }
            } footer: {
                Text("Safari extensions come with Mac apps. Install the app and its extension shows up here.")
                    .font(NookDesign.Font.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .alert(
            Text("Remove \(pendingRemoval?.name ?? "")?"),
            isPresented: Binding(get: { pendingRemoval != nil }, set: { if !$0 { pendingRemoval = nil } }),
            presenting: pendingRemoval
        ) { ext in
            Button("Remove", role: .destructive) {
                extensionManager.uninstallExtension(ext.id)
            }
            Button("Cancel", role: .cancel) {}
        } message: { _ in
            Text("Its data in Vega, such as sign-ins and settings, is deleted.")
        }
        .sheet(item: $consent) { pending in
            ExtensionPermissionView(
                consent: pending.request,
                onGrant: { answer(pending, granted: true) },
                onDeny: { answer(pending, granted: false) }
            )
            .frame(width: NookDesign.Size.dialogMaxWidth)
        }
        .task { await extensionManager.refreshSafariExtensions() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            Task { await extensionManager.refreshSafariExtensions() }
        }
    }

    private var installed: [InstalledExtension] {
        extensionManager.installedExtensions.sorted {
            $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }
    }

    private func scanSafari() {
        isScanningSafari = true
        Task {
            await extensionManager.refreshSafariExtensions()
            isScanningSafari = false
        }
    }

    private func install(_ info: ExtensionManager.SafariExtensionInfo) {
        extensionManager.installSafariExtension(info, presenter: presentConsent) { result in
            guard case .failure(let error) = result else { return }
            if case .cancelled = error { return }
            extensionManager.showErrorAlert(error)
        }
    }

    private func presentConsent(_ request: InstallConsent) async -> Bool {
        await withCheckedContinuation { continuation in
            consent = PendingConsent(
                request: request,
                decide: ResumeOnce(fallback: false) { continuation.resume(returning: $0) }
            )
        }
    }

    private func openWebStore() {
        guard let window = browserManager.openBrowserWindow() else { return }
        browserManager.tabs.open(url: ExtensionStore.chromeWebStoreURL, in: window, placement: .newTab)
    }

    private func answer(_ pending: PendingConsent, granted: Bool) {
        pending.decide(granted)
        consent = nil
    }
}

// MARK: - Extension Icon

/// An extension's own icon on a rounded tile, or Vega's cube when it has none.
private struct ExtensionIconTile: View {
    let image: NSImage?

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
            } else {
                NookSymbol("puzzlepiece.extension", size: 18)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.quaternary)
            }
        }
        .frame(width: 32, height: 32)
        .clipShape(NookDesign.Radius.shape(NookDesign.Radius.md))
    }
}

// MARK: - Safari Extension Row

private struct SafariExtensionRowView: View {
    let info: ExtensionManager.SafariExtensionInfo
    let onInstall: () -> Void

    var body: some View {
        HStack(spacing: NookDesign.Spacing.lg) {
            ExtensionIconTile(image: NSWorkspace.shared.icon(forFile: info.appPath.path))
            VStack(alignment: .leading, spacing: NookDesign.Spacing.xxs) {
                Text(info.name)
                    .font(NookDesign.Font.label)
                    .lineLimit(1)
                Text("Safari · \(info.appPath.lastPathComponent)")
                    .font(NookDesign.Font.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            Button("Install", action: onInstall)
                .buttonStyle(.bordered)
        }
        .padding(.vertical, NookDesign.Spacing.xs)
    }
}

// MARK: - Installed Extension Row

private struct ExtensionRowView: View {
    let `extension`: InstalledExtension
    /// The extension set this row's extension is installed in.
    let extensionManager: ExtensionManager
    let hasOptionsPage: Bool
    let update: ExtensionManager.SafariExtensionInfo?
    let alternative: ExtensionManager.SafariExtensionInfo?
    let onInstall: (ExtensionManager.SafariExtensionInfo) -> Void
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: NookDesign.Spacing.lg) {
            ExtensionIconTile(image: `extension`.iconPath.flatMap(NSImage.init(contentsOfFile:)))
                .opacity(`extension`.isEnabled ? 1 : 0.5)

            VStack(alignment: .leading, spacing: NookDesign.Spacing.xxs) {
                HStack(alignment: .firstTextBaseline, spacing: NookDesign.Spacing.sm) {
                    Text(`extension`.name)
                        .font(NookDesign.Font.label)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                    Text(`extension`.version)
                        .font(NookDesign.Font.caption)
                        .foregroundStyle(.secondary)
                    if let badge {
                        Text(badge)
                            .font(NookDesign.Font.caption)
                            .padding(.horizontal, NookDesign.Spacing.sm)
                            .padding(.vertical, 1)
                            .background(.quaternary, in: NookDesign.Radius.shape(NookDesign.Radius.sm))
                    }
                }
                if let description = `extension`.description, !description.isEmpty {
                    Text(description)
                        .font(NookDesign.Font.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            HStack(spacing: NookDesign.Spacing.md) {
                Toggle(
                    "Enabled",
                    isOn: Binding(
                        get: { `extension`.isEnabled },
                        set: { isEnabled in
                            if isEnabled {
                                extensionManager.enableExtension(`extension`.id)
                            } else {
                                extensionManager.disableExtension(`extension`.id)
                            }
                        }
                    )
                )
                .labelsHidden()

                // FORK: the secondary actions sit in a menu so each row is a name, a switch and one control.
                Menu {
                    if hasOptionsPage {
                        Button("Settings…", nookIcon: "gearshape") { extensionManager.openOptionsPage(`extension`.id) }
                    }
                    Toggle(
                        "Allow in Private Browsing",
                        isOn: Binding(
                            get: { `extension`.allowsPrivateBrowsing },
                            set: { extensionManager.setAllowsPrivateBrowsing(`extension`.id, allowed: $0) }
                        )
                    )
                    if let update {
                        Button("Update from \(update.appPath.lastPathComponent)", nookIcon: "arrow.clockwise") { onInstall(update) }
                    }
                    if let alternative {
                        Button("Switch to the Safari Version", nookIcon: "arrow.clockwise") { onInstall(alternative) }
                    }
                    Divider()
                    Button("Remove…", nookIcon: "trash", role: .destructive, action: onRemove)
                } label: {
                    Image(systemName: "ellipsis")
                }
                // FORK: System Settings' row menu: a round "…" button with no disclosure arrow.
                .menuStyle(.button)
                .buttonStyle(.bordered)
                .buttonBorderShape(.circle)
                .menuIndicator(.hidden)
                .fixedSize()
                .accessibilityLabel("More options for \(`extension`.name)")
            }
        }
        .padding(.vertical, NookDesign.Spacing.xs)
    }

    private var badge: String? {
        if update != nil { return "Update available" }
        if alternative != nil { return "Safari version available" }
        return nil
    }
}

private struct PendingConsent: Identifiable {
    let request: InstallConsent
    let decide: ResumeOnce<Bool>

    var id: UUID { request.id }
}

/// Settings > Extensions for one extension set, the active window's until another is picked.
struct ExtensionSetsSettingsView: View {
    @EnvironmentObject var browserManager: BrowserManager
    @Environment(TabsController.self) private var tabs
    @Environment(\.nookSettings) private var settings
    @State private var picked: UUID?

    var body: some View {
        let registry = ExtensionSetRegistry.shared
        let sets = settings.extensionSets.choices(profiles: tabs.profiles.map(\.id), defaultSet: registry.defaultSetID)
        let active = browserManager.windowRegistry?.activeWindow.map(registry.setID(for:))
        // Only a set a profile uses is shown: asking for any other id would create it.
        let set = [picked, active].compactMap { $0 }.first { id in sets.contains { $0.set == id } }
            ?? sets.first?.set ?? registry.defaultSetID
        ExtensionsSettingsView(
            extensionManager: registry.manager(forSet: set),
            sets: sets,
            shownSet: Binding(get: { set }, set: { picked = $0 })
        )
        .id(set)
    }
}
