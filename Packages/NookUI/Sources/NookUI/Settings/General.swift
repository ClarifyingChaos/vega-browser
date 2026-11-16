// Licensed under GPL-3.0. See LICENSE.
//
//  General.swift
//  Nook
//
//  Created by Maciek Bagiński on 07/12/2025.
//

import SwiftUI
import NookDesign
import NookSettings
import NookWeb

public struct SettingsGeneralTab: View {
    @Environment(TabsController.self) private var tabs
    @Environment(NookSettingsService.self) var nookSettings
    @State private var showingAddSite = false
    @State private var showingAddEngine = false
    /// The Site Search row picked for the − button.
    @State private var selectedSite: UUID?

    public init() {}

    /// The provider list, shared by both platforms' spellings of the row.
    @ViewBuilder
    private func searchEnginePicker(_ settings: NookSettingsService) -> some View {
        @Bindable var settings = settings
        Picker("Default search engine", selection: $settings.searchEngineId) {
            ForEach(SearchProvider.allCases) { provider in
                Text(provider.displayName).tag(provider.rawValue)
            }
            ForEach(nookSettings.customSearchEngines) { engine in
                Text(engine.name).tag(engine.id.uuidString)
            }
        }
    }

    public var body: some View {
        @Bindable var settings = nookSettings
        Form {
            SettingsHero(symbol: "gearshape", title: "General", detail: "Search engine, tabs, startup and how Vega performs.")

            Section {
                #if os(macOS)
                LabeledContent("Default search engine") {
                    HStack(spacing: NookDesign.Spacing.md) {
                        searchEnginePicker(settings)
                            .labelsHidden()

                        Button {
                            showingAddEngine = true
                        } label: {
                            Image(systemName: "plus")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
                #else
                // A picker inside a LabeledContent's trailing slot gets squeezed
                // to "G...gle" at phone width. The Form's own picker row does not,
                // so the add button takes a row of its own.
                searchEnginePicker(settings)
                Button("Add Search Engine…") { showingAddEngine = true }
                #endif

                if let selected = nookSettings.customSearchEngines.first(where: { $0.id.uuidString == nookSettings.searchEngineId }) {
                    LabeledContent {
                        Button("Remove") {
                            nookSettings.customSearchEngines.removeAll { $0.id == selected.id }
                            nookSettings.searchEngineId = SearchProvider.google.rawValue
                        }
                        .foregroundStyle(.red)
                        .buttonStyle(.plain)
                    } label: {
                        Text(selected.name)
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text("Search")
            }

            #if os(macOS)
            Section {
                GoogleAccountRow()
            } header: {
                Text("Account")
            } footer: {
                if !GoogleAccount.shared.isSignedIn {
                    Text("Sign in to sync your spaces, favorites, open tabs and passwords between your Macs.")
                }
            }
            SyncSection()
            #endif

            // FORK: grouped by what they are about, most-used first: search, tabs, startup, performance.
            Section {
                Toggle("Nest tabs opened from links", isOn: $settings.nestTabsFromLinks)
                #if os(macOS)
                Toggle("Keep videos playing in the sidebar", isOn: $settings.autoPictureInPicture)
                #endif
                Picker("Archive tabs after", selection: $settings.archiveAfter) {
                    Text("12 hours").tag(12)
                    Text("24 hours").tag(24)
                    Text("7 days").tag(168)
                    Text("30 days").tag(720)
                    Text("Never").tag(0)
                }
            } header: {
                Text("Tabs")
            } footer: {
                Text("A link's tab sits under the page that opened it. A video left playing moves into a small window above the sidebar controls. Tabs you haven't opened in the archive time move to the Archive; pinned tabs and favorites stay put.")
            }

            Section {
                Picker("On Startup", selection: Binding(
                    get: { nookSettings.startupLoadMode },
                    set: { nookSettings.startupLoadMode = $0 }
                )) {
                    ForEach(StartupLoadMode.allCases) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                #if os(macOS)
                // Quitting and Sparkle updates are both macOS-only concepts.
                Toggle("Warn before quitting Vega", isOn: $settings.askBeforeQuit)
                #endif
            } header: {
                Text("Startup")
            } footer: {
                Text(nookSettings.startupLoadMode.description)
            }

            Section {
                Picker("Tab Management", selection: Binding(
                    get: { nookSettings.tabManagementMode },
                    set: { nookSettings.tabManagementMode = $0 }
                )) {
                    ForEach(TabManagementMode.allCases) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                Button("Unload All Inactive Tabs") {
                    tabs.unloadAllHidden()
                }
            } header: {
                Text("Performance")
            } footer: {
                Text(nookSettings.tabManagementMode.description)
            }

            // FORK: System Settings' editable list: plain rows you select, and one + / − bar under
            // them, in place of a red minus button on every row.
            Section {
                ForEach(nookSettings.siteSearchEntries) { entry in
                    HStack(spacing: NookDesign.Spacing.md) {
                        Circle()
                            .fill(entry.color)
                            .frame(width: NookDesign.Size.statusDot, height: NookDesign.Size.statusDot)
                        Text(entry.name)
                        Spacer()
                        Text(entry.domain)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, NookDesign.Spacing.sm)
                    .padding(.vertical, NookDesign.Spacing.xs)
                    .background(
                        NookDesign.Radius.shape(NookDesign.Radius.sm)
                            .fill(selectedSite == entry.id ? Color.accentColor.opacity(0.25) : .clear)
                    )
                    .contentShape(Rectangle())
                    .onTapGesture { selectedSite = selectedSite == entry.id ? nil : entry.id }
                    .accessibilityAddTraits(selectedSite == entry.id ? [.isButton, .isSelected] : .isButton)
                }

                HStack(spacing: NookDesign.Spacing.sm) {
                    Button { showingAddSite = true } label: { Image(systemName: "plus") }
                        .help("Add Site")
                        .accessibilityLabel("Add Site")
                    Button {
                        if let id = selectedSite {
                            nookSettings.siteSearchEntries.removeAll { $0.id == id }
                            selectedSite = nil
                        }
                    } label: { Image(systemName: "minus") }
                        .disabled(selectedSite == nil)
                        .help("Remove Site")
                        .accessibilityLabel("Remove Site")
                    Spacer()
                    Button("Reset to Defaults") {
                        nookSettings.siteSearchEntries = SiteSearchEntry.defaultSites
                        selectedSite = nil
                    }
                }
                .buttonStyle(.bordered)
            } header: {
                Text("Site Search")
            } footer: {
                Text("Type a prefix in the command palette and press Tab to search a site directly.")
            }
        }
        .formStyle(.grouped)
        .sheet(isPresented: $showingAddSite) {
            SiteSearchEntryEditor(entry: nil) { newEntry in
                nookSettings.siteSearchEntries.append(newEntry)
            }
        }
        .sheet(isPresented: $showingAddEngine) {
            CustomSearchEngineEditor { newEngine in
                nookSettings.customSearchEngines.append(newEngine)
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
        VStack(alignment: .leading, spacing: NookDesign.Spacing.xl) {
            Text("Add Custom Search Engine")
                .font(NookDesign.Font.heading)

            Form {
                Section {
                    TextField("Name (e.g. Startpage)", text: $name)
                    TextField("URL Template (use %@ for query)", text: $urlTemplate)
                }
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
        .padding(NookDesign.Spacing.xxl)
        .frame(width: NookDesign.Size.sheetSmallWidth)
    }
}

#if os(macOS)
private extension SyncCoordinator.Status {
    var isUnavailable: Bool { if case .unavailable = self { return true } else { return false } }
}

/// FORK: spaces, favorites and pinned tabs shared between your Macs, through iCloud Drive or a Google account.
private struct SyncSection: View {
    @State private var sync = SyncCoordinator.shared
    @State private var askingPassphrase = false
    @State private var changingPassphrase = false

    private var detail: String {
        switch sync.status {
        case .off: return "Keeps spaces, favorites and pinned tabs the same on your Macs. Open tabs stay on each Mac."
        case .unavailable(let why): return why
        case .syncing: return "Syncing…"
        case .idle(let last, let others, let waiting):
            let found = others == 0 ? "No other Mac found yet" : "\(others) other \(others == 1 ? "Mac" : "Macs")"
            return "\(found) · synced \(last.formatted(.relative(presentation: .named)))"
                + (waiting > 0 ? " · waiting for iCloud to download \(waiting) \(waiting == 1 ? "file" : "files")" : "")
        case .failed(let message): return "Couldn't sync: \(message)"
        }
    }

    var body: some View {
        Section {
            Toggle("Sync my Macs", isOn: Binding(get: { sync.isEnabled }, set: { sync.isEnabled = $0 }))
            if sync.isEnabled {
                Picker("Sync with", selection: Binding(get: { sync.backend }, set: { sync.backend = $0 })) {
                    ForEach(SyncCoordinator.Backend.allCases) { Text($0.title).tag($0) }
                }
                if sync.backend == .google && !GoogleAccount.shared.isSignedIn {
                    Text("Sign in under Account above to sync with Google.").font(NookDesign.Font.secondary).foregroundStyle(.secondary)
                }
                Toggle("Share open tabs", isOn: Binding(get: { sync.sharesOpenTabs }, set: { sync.sharesOpenTabs = $0 }))
                Text(sync.passwordsEnabled
                     ? "Lists this Mac's open tabs, sealed with your sync passphrase so neither iCloud nor Google can read them. Your other Macs show them under Spaces › Tabs from Other Macs."
                     : "Lists this Mac's open tabs in your sync folder as plain text, without anything after the page address. Turn on password sync to seal them and keep full addresses. Your other Macs show them under Spaces › Tabs from Other Macs.")
                    .font(NookDesign.Font.secondary).foregroundStyle(.secondary)
            }
            if sync.isEnabled {
                Toggle("Sync passwords", isOn: Binding(
                    get: { sync.passwordsEnabled },
                    // Back on with the key this Mac kept; the passphrase is asked only when that key no longer fits.
                    set: { on in
                        if on { Task { if await !sync.resumePasswords() { askingPassphrase = true } } }
                        else { sync.disablePasswords() }
                    }
                ))
                if sync.passwordsEnabled {
                    HStack {
                        Text(sync.passwordStatus ?? "Sealed with your sync passphrase before it leaves this Mac.")
                            .font(NookDesign.Font.secondary).foregroundStyle(.secondary)
                        Spacer()
                        Button("Change Passphrase\u{2026}") { changingPassphrase = true }
                    }
                }
                HStack {
                    Text(detail)
                        .font(NookDesign.Font.secondary)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Sync Now") { sync.syncNow() }
                        .disabled(sync.status == .syncing || sync.status.isUnavailable)
                }
            }
        } header: {
            Text("Sync")
        } footer: {
            if !sync.isEnabled { Text(detail) }
            else if !sync.passwordsEnabled { Text("Passwords sync end to end encrypted with a passphrase only you know. iCloud never sees them.") }
        }
        .sheet(isPresented: $askingPassphrase) { SyncPassphraseSheet(sync: sync, changing: false) }
        .sheet(isPresented: $changingPassphrase) { SyncPassphraseSheet(sync: sync, changing: true) }
    }
}

/// Sign in or out of the Google account that holds the sync files.
/// Sign in or out of the Google account Vega syncs with. Signing in turns sync on through it, so one step is enough.
public struct GoogleAccountRow: View {
    @State private var google = GoogleAccount.shared
    @State private var error: String?

    public init() {}

    public var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: NookDesign.Spacing.xxs) {
                Text(google.isSignedIn ? (google.email ?? "Signed in") : "Not signed in")
                if let error {
                    Text(error).font(NookDesign.Font.secondary).foregroundStyle(.red)
                } else if !google.isAvailable {
                    Text("This build has no Google sign-in set up.").font(NookDesign.Font.secondary).foregroundStyle(.secondary)
                } else if google.isSigningIn {
                    Text("Finish signing in in your browser…").font(NookDesign.Font.secondary).foregroundStyle(.secondary)
                } else {
                    Text("Sync files go in a hidden folder of your Google Drive that only Vega can open.")
                        .font(NookDesign.Font.secondary).foregroundStyle(.secondary)
                }
            }
            Spacer()
            if google.isSignedIn {
                Button("Sign Out") { google.signOut() }
            } else if google.isSigningIn {
                Button("Cancel") { google.cancelSignIn() }
            } else {
                Button("Sign in with Google") {
                    error = nil
                    Task {
                        do {
                            try await google.signIn()
                            let sync = SyncCoordinator.shared
                            sync.backend = .google
                            if sync.isEnabled { sync.syncNow() } else { sync.isEnabled = true }
                        }
                        catch { self.error = error.localizedDescription }
                    }
                }
                .disabled(!google.isAvailable)
            }
        }
    }
}

/// The sync passphrase: the first Mac creates it, every other Mac enters the same one, and any Mac can change it.
public struct SyncPassphraseSheet: View {
    let sync: SyncCoordinator
    /// Changing the passphrase of a sync that is already on, rather than turning it on.
    let changing: Bool

    public init(sync: SyncCoordinator, changing: Bool) {
        self.sync = sync
        self.changing = changing
    }
    @Environment(\.dismiss) private var dismiss
    @State private var passphrase = ""
    @State private var error: String?
    @State private var working = false
    @State private var copied = false
    /// Whether another Mac already chose it: nil while the sync folder is being read or when it can't be.
    @State private var exists: Bool?
    @State private var checked = false

    /// Entering the one another Mac chose, as opposed to choosing one.
    private var entering: Bool { !changing && exists == true }

    private var title: String {
        changing ? "Change Sync Passphrase" : entering ? "Enter Sync Passphrase" : exists == false ? "Create Sync Passphrase" : "Sync Passphrase"
    }

    private var footer: String {
        if changing { return "Your other Macs will ask for the new passphrase. Vega can't show it again, so keep it somewhere safe, like your Passwords app." }
        if entering { return "Enter the passphrase you chose on your other Mac. On that Mac, Change Passphrase\u{2026} sets a new one if you don't have it." }
        if checked && exists == nil { return "Vega couldn't reach your sync folder to see whether another Mac has a passphrase. If one does, enter the same one here." }
        return "Enter this passphrase on your other Macs to sync passwords with them. Vega can't show it again, so keep it somewhere safe, like your Passwords app."
    }

    public var body: some View {
        VStack(spacing: 0) {
            Form {
                Section {
                    HStack {
                        TextField("Passphrase", text: $passphrase)
                            .font(.body.monospaced())
                            .onChange(of: passphrase) { copied = false }
                        if !entering {
                            Button("Suggest") { passphrase = PasswordSyncMeta.suggestedPassphrase() }
                        }
                        Button(copied ? "Copied" : "Copy") {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(passphrase, forType: .string)
                            copied = true
                        }
                        .disabled(passphrase.isEmpty)
                    }
                } header: {
                    Text(title)
                } footer: {
                    if let error { Text(error).foregroundStyle(.red) } else { Text(footer) }
                }
            }
            .formStyle(.grouped)
            HStack {
                if working || (!checked && !changing) { ProgressView().controlSize(.small) }
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                Button(changing ? "Change" : "Turn On") {
                    working = true
                    Task {
                        do {
                            if changing { try await sync.changePassphrase(to: passphrase) }
                            else { try await sync.enablePasswords(passphrase: passphrase) }
                            dismiss()
                        } catch { self.error = error.localizedDescription }
                        working = false
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(passphrase.count < 8 || working)
            }
            .padding(NookDesign.Spacing.xl)
        }
        .frame(width: 480)
        .task {
            guard !changing else { return }
            exists = await sync.passphraseExists()
            checked = true
        }
    }
}
#endif
