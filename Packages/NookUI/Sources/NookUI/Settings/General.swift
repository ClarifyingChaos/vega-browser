// Licensed under GPL-3.0. See LICENSE.
//
//  General.swift
//  Nook
//
//  Created by Maciek Bagiński on 07/12/2025.
//

import SwiftUI
#if os(macOS)
import AppKit
#endif
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
    /// The profile whose account and sync are shown; nil follows the window in front.
    @State private var accountProfile: UUID?

    /// The profile of the window in front, else the first one.
    private var currentProfileID: UUID? {
        tabs.windowRegistry.activeWindow.flatMap { tabs.profileID(of: $0) } ?? tabs.profiles.first?.id
    }

    public init() {}

    public var body: some View {
        @Bindable var settings = nookSettings
        Form {
            SettingsHero(symbol: "gearshape", title: "General", detail: "Search engine, tabs, startup and how Vega performs.")

            Section {
                SearchEngineList()
                Button("Add Search Engine\u{2026}", nookIcon: "plus") { showingAddEngine = true }
                Toggle(isOn: $settings.searchSuggestionsEnabled) {
                    Text("Search suggestions")
                    Text("Sends what you type to the engine. Never in private windows. Google only for now.")
                }
            } header: {
                Text("Search")
            }

            #if os(macOS)
            // Each profile has its own Google account and sync, so these sections follow the profile picked here
            // (the window in front to begin with).
            if tabs.profiles.count > 1 {
                Section {
                    Picker("Profile", selection: Binding(get: { accountProfile ?? currentProfileID }, set: { accountProfile = $0 })) {
                        ForEach(tabs.profiles) { Text($0.name).tag(UUID?.some($0.id)) }
                    }
                } footer: {
                    Text("Each profile signs in to its own account and syncs on its own.")
                }
            }
            Section {
                GoogleAccountRow(profileID: accountProfile ?? currentProfileID)
                    .id(accountProfile ?? currentProfileID)
            } header: {
                Text("Account")
            } footer: {
                if !GoogleAccount.forProfile(accountProfile ?? currentProfileID).isSignedIn {
                    Text("Sign in to sync your spaces, favorites, open tabs and passwords between your Macs.")
                }
            }
            SyncSection(profileID: accountProfile ?? currentProfileID)
                .id(accountProfile ?? currentProfileID)
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
                #if os(macOS)
                OpenAtLoginToggle()
                #endif
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

            #if os(macOS)
            DownloadsSection()
            #endif

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

#if os(macOS)
private extension SyncCoordinator.Status {
    var isUnavailable: Bool { if case .unavailable = self { return true } else { return false } }
}

/// FORK: spaces, favorites and pinned tabs shared between your Macs, through iCloud Drive or a Google account.
private struct SyncSection: View {
    let profileID: UUID?
    @State private var sync: SyncCoordinator

    init(profileID: UUID?) {
        self.profileID = profileID
        _sync = State(initialValue: SyncCoordinator.forProfile(profileID))
    }

    @State private var askingPassphrase = false
    /// Choosing the sync passphrase that starts sync (passwords are a separate switch).
    @State private var settingUpPassphrase = false
    @State private var changingPassphrase = false
    @State private var removing: SyncDevice?
    @State private var lockingOut: String?

    private var detail: String {
        switch sync.status {
        case .off: return "Keeps spaces, favorites, pinned tabs, open tabs, passwords and settings the same on your Macs."
        case .unavailable(let why): return why
        case .syncing: return "Syncing…"
        case .needsPassphrase: return "Paused until you choose a sync passphrase."
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
            if let line = sync.removedMessage {
                Text(line).font(NookDesign.Font.secondary).foregroundStyle(.secondary)
            }
            // FORK: sync sends nothing until this Mac has the passphrase that seals it.
            if sync.isEnabled && sync.status == .needsPassphrase {
                HStack {
                    Text("Sync is paused. Choose a sync passphrase first: your spaces, favorites, tabs and settings are sealed with it before they leave this Mac, so iCloud, Google and the server can't read them.")
                        .font(NookDesign.Font.secondary).foregroundStyle(.orange)
                    Spacer()
                    Button("Set Passphrase\u{2026}") { settingUpPassphrase = true }
                }
            }
            if sync.isEnabled {
                Picker("Sync with", selection: Binding(get: { sync.backend }, set: { sync.backend = $0 })) {
                    ForEach(SyncCoordinator.Backend.available) { Text($0.title).tag($0) }
                }
                if sync.backend == .automatic && sync.status != .off {
                    Text("Syncing through \(sync.active.title). If it can't be reached, Vega moves to the next place and tries the first again every minute.")
                        .font(NookDesign.Font.secondary).foregroundStyle(.secondary)
                    // FORK: a Mac on the fallback can't see Macs still on the server, so say why it left.
                    if sync.active != .server, let problem = sync.serverProblem {
                        Text("The Vega Sync server failed: \(problem) Your other Macs may not see this one until it works again.")
                            .font(NookDesign.Font.secondary).foregroundStyle(.orange)
                    }
                }
                if (sync.backend == .google || sync.backend == .server || sync.backend == .automatic) && !GoogleAccount.forProfile(profileID).isSignedIn {
                    if GoogleAccount.forProfile(profileID).signInExpired {
                        Text("Your Google sign-in expired. Sign in again under Account above to sync through the Vega Sync server.")
                            .font(NookDesign.Font.secondary).foregroundStyle(.orange)
                    } else {
                        Text("Sign in under Account above to sync with Google.").font(NookDesign.Font.secondary).foregroundStyle(.secondary)
                    }
                }
                Toggle("Keep open tabs the same on my Macs", isOn: Binding(get: { sync.mirrorsTabs }, set: { sync.mirrorsTabs = $0 }))
                Text("Tabs you open or close on one Mac open or close on the others. Each Mac keeps its own selected tab.")
                    .font(NookDesign.Font.secondary).foregroundStyle(.secondary)
                Toggle("Also list open tabs under Spaces \u{203A} Tabs from Other Macs", isOn: Binding(get: { sync.sharesOpenTabs }, set: { sync.sharesOpenTabs = $0 }))
                Text("Lists this Mac's open tabs, sealed with your sync passphrase so neither iCloud nor Google can read them. Your other Macs show them under Spaces › Tabs from Other Macs.")
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
                } else if sync.hasPassphrase {
                    HStack {
                        Text("Your spaces, favorites, tabs and settings are sealed with your sync passphrase before they leave this Mac.")
                            .font(NookDesign.Font.secondary).foregroundStyle(.secondary)
                        Spacer()
                        Button("Change Passphrase\u{2026}") { changingPassphrase = true }
                    }
                }
                if let step = sync.progress {
                    VStack(alignment: .leading, spacing: NookDesign.Spacing.xs) {
                        ProgressView(value: Double(step.step), total: Double(SyncProgress.steps))
                        Text("\(step.label)\u{2026} (\(step.step) of \(SyncProgress.steps))")
                            .font(NookDesign.Font.secondary).foregroundStyle(.secondary)
                    }
                    .animation(NookDesign.Motion.standard, value: step)
                    .accessibilityElement(children: .combine)
                }
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(detail)
                        if sync.progress == nil, let summary = sync.summary { Text(summary) }
                    }
                    .font(NookDesign.Font.secondary)
                    .foregroundStyle(.secondary)
                    Spacer()
                    Button("Sync Now") { sync.syncNow() }
                        .disabled(sync.progress != nil || sync.status == .syncing || sync.status.isUnavailable)
                }
                if !sync.devices.isEmpty {
                    ForEach(sync.devices) { device in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(device.name)
                                Text("Last synced \(device.lastSeen.formatted(.relative(presentation: .named)))")
                                    .font(NookDesign.Font.secondary).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("Remove\u{2026}") { removing = device }
                        }
                    }
                    Text("Removing a Mac stops syncing with it right away. It deletes its synced data the next time Vega opens on it and can reach the sync folder. If you sync passwords, Vega then asks for a new passphrase, which locks it out of them at once.")
                        .font(NookDesign.Font.secondary).foregroundStyle(.secondary)
                }
                // Settings from the other Mac arrive in the background and apply at the next launch.
                if let line = sync.settingsStatus {
                    HStack {
                        Text(line).font(NookDesign.Font.secondary).foregroundStyle(.secondary)
                        Spacer()
                        Button("Restart Vega") {
                            let configuration = NSWorkspace.OpenConfiguration()
                            configuration.createsNewApplicationInstance = true
                            NSWorkspace.shared.openApplication(at: Bundle.main.bundleURL, configuration: configuration) { _, _ in
                                DispatchQueue.main.async { NSApp.terminate(nil) }
                            }
                        }
                    }
                }
            }
        } header: {
            Text("Sync")
        } footer: {
            if !sync.isEnabled { Text(detail) }
            else { Text("Spaces, favorites, settings and open tabs are sealed with your sync passphrase, and so are passwords when you sync them: iCloud, Google and the Vega Sync server can't read them; only the names of your Macs and profile stay readable. A Mac with an older Vega still gets a readable copy of your spaces until it updates.") }
        }
        .nookConfirm("Remove \(removing?.name ?? "this Mac") from sync?",
                     message: "The next time Vega opens on it, it turns sync off and deletes the spaces, favorites, tabs, passwords, settings, history and website sign-ins it got through sync. Your other Macs keep theirs. It can join again by turning sync on.",
                     confirm: "Remove", isPresented: Binding(get: { removing != nil }, set: { if !$0 { removing = nil } })) {
            if let device = removing {
                sync.removeDevice(device.id)
                // A new passphrase means a new key: the removed Mac can't open what is saved from now on.
                if sync.hasPassphrase { lockingOut = device.name }
            }
        }
        .sheet(isPresented: $askingPassphrase) { SyncPassphraseSheet(sync: sync, changing: false) }
        .sheet(isPresented: $settingUpPassphrase) { SyncPassphraseSheet(sync: sync, changing: false, sealOnly: true) }
        .sheet(isPresented: $changingPassphrase) { SyncPassphraseSheet(sync: sync, changing: true) }
        .sheet(isPresented: Binding(get: { lockingOut != nil }, set: { if !$0 { lockingOut = nil } })) {
            SyncPassphraseSheet(sync: sync, changing: true, reason: "Set a new passphrase so \(lockingOut ?? "the removed Mac") can't read what you sync from now on, even before it deletes its own copy.")
        }
    }
}

/// Sign in or out of the Google account that holds the sync files.
/// Sign in or out of the Google account Vega syncs with. Signing in turns sync on through it, so one step is enough.
public struct GoogleAccountRow: View {
    let profileID: UUID?
    @Environment(TabsController.self) private var tabs
    @State private var google: GoogleAccount
    @State private var error: String?

    public init(profileID: UUID? = nil) {
        self.profileID = profileID
        _google = State(initialValue: GoogleAccount.forProfile(profileID))
    }

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
                            // The first profile on a fresh Mac takes the account's profile instead of making a second.
                            let sync = SyncCoordinator.forProfile(profileID)
                            if ProfileScope.isPrimary(profileID) { await ProfileAdoption.reconcileFirstProfile(tabs: tabs) }
                            sync.backend = .automatic
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
    /// Why it is asked, said before the usual words (a Mac was just removed).
    let reason: String?
    /// Sets only the passphrase that seals sync; passwords stay a separate switch.
    let sealOnly: Bool

    public init(sync: SyncCoordinator, changing: Bool, reason: String? = nil, sealOnly: Bool = false) {
        self.sync = sync
        self.changing = changing
        self.reason = reason
        self.sealOnly = sealOnly
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
        if changing { return (reason.map { $0 + " " } ?? "") + "Your other Macs will ask for the new passphrase. Vega can't show it again, so keep it somewhere safe, like your Passwords app." }
        if entering { return "Enter the passphrase you chose on your other Mac. On that Mac, Change Passphrase\u{2026} sets a new one if you don't have it." }
        if checked && exists == nil { return "Vega couldn't reach your sync folder to see whether another Mac has a passphrase. If one does, enter the same one here." }
        return "Enter this passphrase on your other Macs to sync with them. Vega can't show it again, so keep it somewhere safe, like your Passwords app."
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
                Button(changing ? "Change" : sealOnly ? "Set Passphrase" : "Turn On") {
                    working = true
                    Task {
                        do {
                            if changing { try await sync.changePassphrase(to: passphrase) }
                            else if sealOnly { try await sync.setUpPassphrase(passphrase) }
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

#if os(macOS)
/// Where downloads go: a folder you choose, or a Save panel for every file (Safari's and Chrome's two settings).
private struct DownloadsSection: View {
    @AppStorage(DownloadLocation.folderKey) private var folderPath = ""
    @AppStorage(DownloadLocation.askKey) private var asksEachTime = false

    var body: some View {
        Section {
            LabeledContent("Save Downloads To") {
                HStack(spacing: NookDesign.Spacing.sm) {
                    Image(nsImage: NSWorkspace.shared.icon(forFile: folder.path))
                        .resizable()
                        .frame(width: 16, height: 16)
                    Text(FileManager.default.displayName(atPath: folder.path))
                    Button("Choose…", action: choose)
                }
            }
            .disabled(asksEachTime)
            Toggle("Ask where to save each download", isOn: $asksEachTime)
        } header: {
            Text("Downloads")
        } footer: {
            Text(asksEachTime ? "Vega asks for a place and a name before each file is saved." : "Files are saved straight to this folder.")
        }
    }

    private var folder: URL { _ = folderPath; return DownloadLocation.folder }

    private func choose() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = folder
        panel.prompt = "Choose"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        folderPath = url.path
    }
}
#endif
