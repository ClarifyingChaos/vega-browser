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

    var body: some View {
        Form {
            SettingsHero(symbol: "puzzlepiece.extension", title: "Extensions", detail: "Add, turn off or remove browser extensions.")

            if sets.count > 1, let shownSet {
                Section {
                    Picker("Profiles", selection: shownSet) {
                        ForEach(sets, id: \.set) { choice in
                            Text(choice.members.compactMap { id in tabs.profiles.first { $0.id == id }?.name }.joined(separator: ", "))
                                .tag(choice.set)
                        }
                    }
                }
            }

            Section {
                Button("Install Extension…", nookIcon: "plus") {
                    extensionManager.showExtensionInstallDialog(presenter: presentConsent)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.vertical, NookDesign.Spacing.sm)
            }

            if extensionManager.installedExtensions.isEmpty && extensionManager.uninstalledSafariExtensions.isEmpty {
                Section {
                    VStack(spacing: NookDesign.Spacing.lg) {
                        NookSymbol("puzzlepiece.extension", size: 60)
                            .font(NookDesign.Font.hero)
                            .foregroundStyle(.secondary)
                        Text("No Extensions Installed")
                            .font(NookDesign.Font.titleLarge)
                        Text("Install browser extensions to enhance your browsing experience")
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                }
            } else if !extensionManager.installedExtensions.isEmpty {
                Section("Installed Extensions") {
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
                        .padding(.vertical, NookDesign.Spacing.md)
                    }
                }
            }

            Section {
                if extensionManager.safariExtensions == nil {
                    HStack(spacing: NookDesign.Spacing.md) {
                        ProgressView()
                            .controlSize(.small)
                        Text("Scanning...")
                            .foregroundStyle(.secondary)
                    }
                } else if extensionManager.uninstalledSafariExtensions.isEmpty {
                    Text("No Safari Web Extensions found on this Mac.")
                        .font(NookDesign.Font.caption)
                        .foregroundStyle(.secondary)
                }
                ForEach(extensionManager.uninstalledSafariExtensions) { ext in
                    SafariExtensionRowView(info: ext, isAlreadyInstalled: false, onInstall: { install(ext) })
                }
            } header: {
                Text("Safari Extensions")
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

    private func answer(_ pending: PendingConsent, granted: Bool) {
        pending.decide(granted)
        consent = nil
    }
}

// MARK: - Safari Extension Row

private struct SafariExtensionRowView: View {
    let info: ExtensionManager.SafariExtensionInfo
    let isAlreadyInstalled: Bool
    let onInstall: () -> Void

    var body: some View {
        HStack(spacing: NookDesign.Spacing.lg) {
            Image(systemName: "safari")
                .font(NookDesign.Font.titleLarge)
                .foregroundStyle(.blue)
                .frame(
                    width: NookDesign.Size.settingsIcon,
                    height: NookDesign.Size.settingsIcon
                )

            VStack(alignment: .leading, spacing: NookDesign.Spacing.xxs) {
                Text(info.name)
                    .font(NookDesign.Font.label)
                    .lineLimit(1)
                Text(info.appPath.lastPathComponent)
                    .font(NookDesign.Font.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            if isAlreadyInstalled {
                Text("Installed")
                    .font(NookDesign.Font.caption)
                    .foregroundStyle(.secondary)
            } else {
                Button("Install") {
                    onInstall()
                }
                .buttonStyle(.bordered)
            }
        }
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
        HStack(spacing: NookDesign.Spacing.xl) {
            // FORK: roomier row: a larger icon, the name with its version, a description of up to two lines.
            Group {
                if let iconPath = `extension`.iconPath,
                    let nsImage = NSImage(contentsOfFile: iconPath)
                {
                    Image(nsImage: nsImage)
                        .resizable()
                        .interpolation(.high)
                        .scaledToFit()
                } else {
                    Image(systemName: "puzzlepiece.extension")
                        .foregroundStyle(.blue)
                }
            }
            .frame(width: 36, height: 36)
            .clipShape(NookDesign.Radius.shape(NookDesign.Radius.md))

            VStack(alignment: .leading, spacing: NookDesign.Spacing.xs) {
                HStack(alignment: .firstTextBaseline, spacing: NookDesign.Spacing.sm) {
                    Text(`extension`.name)
                        .font(NookDesign.Font.title)
                        .fontWeight(.medium)
                        .lineLimit(1)
                    Text("v\(`extension`.version)")
                        .font(NookDesign.Font.caption)
                        .foregroundStyle(.secondary)
                }
                if let description = `extension`.description, !description.isEmpty {
                    Text(description)
                        .font(NookDesign.Font.secondary)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer()

            // Controls
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
                    Toggle(
                        "Allow in Private Browsing",
                        isOn: Binding(
                            get: { `extension`.allowsPrivateBrowsing },
                            set: { extensionManager.setAllowsPrivateBrowsing(`extension`.id, allowed: $0) }
                        )
                    )
                    if hasOptionsPage {
                        Button("Settings…", nookIcon: "gearshape") { extensionManager.openOptionsPage(`extension`.id) }
                    }
                    if let update {
                        Button("Update from \(update.appPath.lastPathComponent)", nookIcon: "arrow.triangle.2.circlepath") { onInstall(update) }
                    }
                    if let alternative {
                        Button("Switch to the Safari version", nookIcon: "safari") { onInstall(alternative) }
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
