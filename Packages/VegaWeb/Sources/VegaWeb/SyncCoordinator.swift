// Licensed under GPL-3.0. See LICENSE.
//
//  SyncCoordinator.swift
//  VegaWeb
//
//  FORK: runs `SyncMerge` and `SyncFolder` for the app. Off until the person turns it on. Every
//  tick it applies what other Macs wrote, then writes this Mac's snapshot if it changed.
//  shortcut: polls every 20 s instead of watching the folder; local edits reach the other Mac
//  within one tick plus iCloud's own delay. Upgrade to a file-system event watcher if that lags.
//

import AppKit
import CryptoKit
import Foundation
import VegaTabsCore
import Observation
import Security
import os

@MainActor @Observable
public final class SyncCoordinator {
    /// The first profile's sync, with the names every earlier version used.
    public static let shared = SyncCoordinator(profileID: nil)

    // FORK: each profile syncs on its own: its own account, folder, passphrase and switches. The profile's spaces and
    // tabs are the only ones that go to its account.
    private static var others: [UUID: SyncCoordinator] = [:]
    /// Set at launch so a coordinator made later (a new profile) can find the tabs.
    private static weak var tabsController: TabsController?

    public static func forProfile(_ profileID: UUID?) -> SyncCoordinator {
        guard let profileID, !ProfileScope.isPrimary(profileID) else { return shared }
        if let existing = others[profileID] { return existing }
        let coordinator = SyncCoordinator(profileID: profileID)
        others[profileID] = coordinator
        if let tabs = tabsController { coordinator.start(tabs: tabs) }
        return coordinator
    }

    /// Called once at launch with the controller that owns the tree: starts every profile that has sync on.
    public static func startAll(tabs: TabsController) {
        tabsController = tabs
        shared.start(tabs: tabs)
        for profile in tabs.profiles { _ = forProfile(profile.id) }
    }

    /// The profile this coordinator syncs; nil for the first one, which keeps the original names.
    public let profileID: UUID?
    private let suffix: String
    private var passwordsKey: String { "fork.sync.passwords" + suffix }
    private var backendKey: String { "fork.sync.backend" + suffix }
    private var enabledKey: String { "fork.sync.enabled" + suffix }
    private var openTabsKey: String { "fork.sync.openTabs" + suffix }
    private var mirrorKey: String { "fork.sync.mirrorTabs" + suffix }
    private var fingerprintKey: String { "fork.sync.passwordsFingerprint" + suffix }
    private var keyService: String { "\(KeychainVault.keychainPrefix).syncKey" + suffix }
    /// The profile whose spaces and tabs go to this account: nil syncs every space (a first profile with no others).
    private var scopeProfile: UUID? { profileID ?? ProfileScope.primaryID }

    private init(profileID: UUID?) {
        self.profileID = profileID
        let suffix = ProfileScope.suffix(for: profileID)
        self.suffix = suffix
        isEnabled = UserDefaults.standard.bool(forKey: "fork.sync.enabled" + suffix)
        // Macs set up before Automatic existed move to it once; a later manual choice sticks.
        if !UserDefaults.standard.bool(forKey: "fork.sync.automaticMigrated" + suffix) {
            UserDefaults.standard.set(true, forKey: "fork.sync.automaticMigrated" + suffix)
            UserDefaults.standard.set(Backend.automatic.rawValue, forKey: "fork.sync.backend" + suffix)
        }
        let chosen = Backend(rawValue: UserDefaults.standard.string(forKey: "fork.sync.backend" + suffix) ?? "") ?? .automatic
        backend = chosen
        active = chosen == .automatic ? .iCloud : chosen
        sharesOpenTabs = UserDefaults.standard.bool(forKey: "fork.sync.openTabs" + suffix)
        mirrorsTabs = UserDefaults.standard.object(forKey: "fork.sync.mirrorTabs" + suffix) as? Bool ?? true
        passwordsEnabled = UserDefaults.standard.bool(forKey: "fork.sync.passwords" + suffix)
        if backend == .automatic { active = resolve() }
    }

    public enum Status: Equatable {
        case off
        /// No place to sync to yet: iCloud Drive is off, or nobody is signed in to Google.
        case unavailable(String)
        case syncing
        case idle(lastSync: Date, otherMacs: Int, waitingForDownload: Int)
        case failed(String)
    }

    public enum PasswordSyncError: LocalizedError {
        case syncOff, noFolder, wrongPassphrase, emptyPassphrase
        public var errorDescription: String? {
            switch self {
            case .syncOff: return "Turn on Sync with iCloud Drive first."
            case .noFolder: return "There's nowhere to sync to yet: turn on iCloud Drive or sign in with Google."
            case .wrongPassphrase: return "That isn't the passphrase this sync was set up with."
            case .emptyPassphrase: return "Choose a passphrase of at least 8 characters."
            }
        }
    }

    public enum Backend: String, CaseIterable, Identifiable, Sendable {
        case automatic, server, iCloud, google
        public var id: String { rawValue }
        public var title: String {
            switch self {
            case .automatic: "Automatic (server, then iCloud, then Google)"
            case .iCloud: "iCloud Drive"
            case .google: "Google account"
            case .server: "Vega Sync server"
            }
        }
        /// The places to choose from: the server only once its address is set (`defaults write com.vega.browser
        /// fork.sync.serverURL https://…`), since nobody runs one by default.
        public static var available: [Backend] { allCases }
        /// Vega's own sync server, unless `fork.sync.serverURL` points somewhere else.
        public static let defaultServer = "https://vega-sync.ortfolio-v2.workers.dev/"
        /// The order Automatic tries: the server first, iCloud Drive second, a Google account's Drive last.
        static let order: [Backend] = [.server, .iCloud, .google]
        public static var serverURL: URL? {
            guard let url = URL(string: UserDefaults.standard.string(forKey: "fork.sync.serverURL") ?? defaultServer) else { return nil }
            let local = url.host == "127.0.0.1" || url.host == "localhost"
            return url.scheme == "https" || (url.scheme == "http" && local) ? url : nil
        }
    }

    private static let logger = Logger(subsystem: "com.vega.browser", category: "sync")
    private static let deviceKey = "fork.sync.deviceID"
    /// How soon the next round runs while things are changing, and how far it backs off when a round finds nothing
    /// new: 20 s, 40 s ... up to `slowestInterval`. A change here, coming back to Vega, or Sync Now starts it over.
    private static let interval: Duration = .seconds(20)
    /// The longest wait between checks. Google Drive has no way to tell us about a change, so it is asked, and a quiet
    /// check is one small request; iCloud Drive's folder is watched, so its timed check only backs the watcher up.
    private var slowestInterval: Duration { active == .google ? .seconds(30) : .seconds(120) }
    /// The server's live connection: another Mac's write starts a round here within a second or two.
    @ObservationIgnored private var liveConnection: ServerLive?
    /// A change here is sent after it stops for this long, and never more often than `minGap`.
    private static let settleDelay: Duration = .seconds(4)
    private static let minGap: TimeInterval = 15

    public private(set) var status: Status = .off
    /// Where password sync stands, shown under its switch.
    public private(set) var passwordStatus: String?
    /// Set when settings from another Mac were applied and need a restart.
    public internal(set) var settingsStatus: String?
    /// The other Macs in this chain, as of the last sync (removed ones left out).
    public private(set) var devices: [SyncDevice] = []
    /// Set when another Mac took this one out of the chain.
    public internal(set) var removedMessage: String?
    @ObservationIgnored var removedIDs: Set<UUID> = []
    @ObservationIgnored private var rejoining = false
    /// The step a sync round is on, while it runs.
    public private(set) var progress: SyncProgress?
    /// What the last round covered, shown under the sync status.
    public private(set) var summary: String?
    /// The tabs open on the other Macs, as of the last sync.
    public private(set) var otherMacsTabs: [OpenTabsSnapshot] = []
    /// Whether this Mac lists its open tabs (titles and addresses) in the sync folder for the others.
    // Stored, not read from UserDefaults on each access, so the switches redraw when they change.
    public var sharesOpenTabs: Bool {
        didSet {
            UserDefaults.standard.set(sharesOpenTabs, forKey: openTabsKey)
            lastOpenTabs = nil
            if isEnabled { syncNow() }
        }
    }
    /// Whether the open tabs themselves are kept the same on every Mac, not just listed. On unless switched off.
    public var mirrorsTabs: Bool {
        didSet {
            UserDefaults.standard.set(mirrorsTabs, forKey: mirrorKey)
            lastWritten = nil
            if isEnabled { syncNow() }
        }
    }
    @ObservationIgnored private var lastOpenTabs: [OpenTabsSnapshot.Entry]?
    @ObservationIgnored private weak var tabs: TabsController?
    @ObservationIgnored private var loop: Task<Void, Never>?
    /// The loop's wait between rounds: cancelling it starts the next round now.
    @ObservationIgnored private var sleeper: Task<Void, Never>?
    /// Rounds in a row that found nothing to send or take.
    @ObservationIgnored private var quietRounds = 0
    /// Set by any step that sent or took something in this round.
    @ObservationIgnored var roundFoundWork = false
    /// A nudge that arrived while a round was running: the next round starts at once.
    @ObservationIgnored private var rerunRequested = false
    /// Whether this round shows its steps in Settings: only the ones the person asked for.
    @ObservationIgnored private var showsProgress = true
    @ObservationIgnored private var lastRoundEnd = Date.distantPast
    @ObservationIgnored private var settleTask: Task<Void, Never>?
    @ObservationIgnored private var watcher: FolderWatcher?
    @ObservationIgnored private var watchTask: Task<Void, Never>?
    /// Keeps macOS from slowing the sync loop (App Nap) while Vega sits hidden or minimised: a Mac whose Vega is in
    /// the background must still send and take changes within a round or two.
    @ObservationIgnored private var activity: NSObjectProtocol?
    @ObservationIgnored private var lastWritten: SyncSnapshot?
    /// Whether some Mac in the chain still reads only plain files (an older Vega, or one without the passphrase):
    /// then the plain copy is written beside the sealed one. Assumed until the first round has looked.
    @ObservationIgnored var plainNeeded = true
    /// How the last snapshot was written (sealed, plain too), so a change of either writes again.
    @ObservationIgnored private var lastWrittenMode: (sealed: Bool, plain: Bool)?
    @ObservationIgnored private var observers: [Any] = []

    /// Where Automatic is syncing right now (the chosen place otherwise). Read by Settings to say "via iCloud Drive".
    public private(set) var active: Backend
    /// Places that just failed, and when Automatic may try them again.
    @ObservationIgnored private var coolingDown: [Backend: Date] = [:]
    private static let retryAfter: TimeInterval = 300

    /// The first place in order that can be used and hasn't just failed; failing that, the first that can be used.
    private func resolve() -> Backend {
        let usable = Backend.order.filter { store(for: $0) != nil }
        let now = Date()
        return usable.first { (coolingDown[$0] ?? .distantPast) <= now } ?? usable.first ?? .iCloud
    }

    /// Moves Automatic to another place, starting each side from scratch as a manual change does. Returns whether it moved.
    private func switchActive(to next: Backend) -> Bool {
        guard backend == .automatic, next != active else { return false }
        Self.logger.notice("sync moves from \(self.active.rawValue, privacy: .public) to \(next.rawValue, privacy: .public)")
        active = next
        lastWritten = nil
        forgetPasswordFingerprint()
        begin()
        return true
    }

    public var backend: Backend {
        didSet {
            guard backend != oldValue else { return }
            UserDefaults.standard.set(backend.rawValue, forKey: backendKey)
            if backend == .automatic { coolingDown = [:]; active = resolve() } else { active = backend }
            // Another place is another set of files: start each side from scratch.
            lastWritten = nil
            forgetPasswordFingerprint()
            if isEnabled { begin() }
        }
    }

    /// Where this Mac syncs right now, or why it can't.
    func currentStore() -> (store: any SyncBlobStore, missing: String?)? {
        store(for: active).map { ($0, nil) }
    }

    private func store(for place: Backend) -> (any SyncBlobStore)? {
        switch place {
        case .automatic:
            return nil
        case .iCloud:
            // A scripted run points two copies of Vega at one folder, standing in for two Macs.
            let override = UserDefaults.standard.string(forKey: "fork.sync.testFolder").map { URL(fileURLWithPath: $0, isDirectory: true) }
            guard var url = override ?? FolderBlobStore.iCloudDrive() else { return nil }
            // One iCloud account holds every profile's files: each other profile gets its own folder.
            if !suffix.isEmpty, let profileID { url.appendPathComponent("Profiles/\(profileID.uuidString)", isDirectory: true) }
            return FolderBlobStore(url: url)
        case .google:
            return GoogleAccount.forProfile(profileID).store()
        case .server:
            // Signed in with the same Google account; the server keeps one set of files per account.
            guard let url = Backend.serverURL else { return nil }
            return GoogleAccount.forProfile(profileID).serverStore(url: url)
        }
    }

    private var missingMessage: String {
        switch active {
        case .automatic: "Sign in with Google or turn on iCloud Drive to sync."
        case .iCloud: "Turn on iCloud Drive in System Settings › Apple Account › iCloud, then try again."
        case .google: "Sign in with Google to sync."
        case .server: Backend.serverURL == nil ? "Set the Vega Sync server's address first." : "Sign in with Google to use Vega Sync."
        }
    }

    public var isEnabled: Bool {
        didSet {
            guard isEnabled != oldValue else { return }
            UserDefaults.standard.set(isEnabled, forKey: enabledKey)
            if isEnabled { rejoining = true; removedMessage = nil }
            isEnabled ? begin() : stop()
        }
    }

    // The switch only, stored so Settings redraws when it changes (a computed read of UserDefaults left the toggle
    // showing On after it was turned off, so the next click turned it back on and asked for the passphrase).
    public private(set) var passwordsEnabled: Bool

    // What the last written password snapshot covered. Kept across launches: with it only in memory, every launch
    // read every saved password to write a snapshot again, and the Keychain asked about each one.
    @ObservationIgnored private var forcePasswordWrite = false
    /// When to try again for logins that could not be read last time.
    @ObservationIgnored private var passwordRetryAt: Date?
    private var passwordRetryDue: Bool { passwordRetryAt.map { Date() >= $0 } ?? false }
    /// Saved logins and how many of them wait for an older Vega's Keychain approval, as of the last round.
    @ObservationIgnored private var passwordTotals: (total: Int, waiting: Int)?
    private func forgetPasswordFingerprint() {
        UserDefaults.standard.removeObject(forKey: fingerprintKey)
        forcePasswordWrite = true
    }
    private static func digest(_ light: [PasswordRecord]) -> String {
        let lines = light.map { "\($0.key)\($0.deleted ? "\u{0}" : "")|\(Int($0.modified.timeIntervalSince1970))" }.sorted().joined(separator: "\n")
        return SHA256.hash(data: Data(lines.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    // MARK: - Password sync

    /// Sets up password sync on this Mac: the first Mac creates the passphrase's salt in the shared
    /// folder, the others must enter the same passphrase. The derived key stays in this Mac's Keychain.
    public func enablePasswords(passphrase: String) async throws {
        guard isEnabled else { throw PasswordSyncError.syncOff }
        guard let place = currentStore() else { throw PasswordSyncError.noFolder }
        guard passphrase.count >= 8 else { throw PasswordSyncError.emptyPassphrase }
        let store = PasswordSyncStore(store: place.store)
        let key: SymmetricKey
        if let meta = try await store.meta() {
            guard let k = await Task.detached(operation: { meta.key(for: passphrase) }).value else { throw PasswordSyncError.wrongPassphrase }
            key = k
        } else {
            let made = try await Task.detached { try PasswordSyncMeta.create(passphrase: passphrase) }.value
            try await store.writeMeta(made.meta)
            key = made.key
        }
        saveKey(key)
        UserDefaults.standard.set(true, forKey: passwordsKey)
        passwordsEnabled = true
        forgetPasswordFingerprint()
        await tick()
    }

    /// True when another Mac already chose the passphrase (this Mac must enter the same one), false when this
    /// Mac would create it, nil when the sync folder can't be read.
    public func passphraseExists() async -> Bool? {
        guard isEnabled, let place = currentStore() else { return nil }
        // A folder with no passphrase yet is "false" (this Mac creates it); only a failed read is nil.
        do { return try await PasswordSyncStore(store: place.store).meta() != nil } catch { return nil }
    }

    /// A new passphrase for every Mac: a new salt and key, this Mac's passwords sealed again with it. The other
    /// Macs notice the change and ask for the new passphrase.
    public func changePassphrase(to passphrase: String) async throws {
        guard isEnabled, passwordsEnabled else { throw PasswordSyncError.syncOff }
        guard let place = currentStore() else { throw PasswordSyncError.noFolder }
        guard passphrase.count >= 8 else { throw PasswordSyncError.emptyPassphrase }
        let made = try await Task.detached { try PasswordSyncMeta.create(passphrase: passphrase) }.value
        try await PasswordSyncStore(store: place.store).writeMeta(made.meta)
        saveKey(made.key)
        forgetPasswordFingerprint()
        await tick()
    }

    /// Turns password sync back on with the key this Mac kept, without asking, when that key still opens the
    /// sync folder's passphrase. False when it has to ask: no key, a folder with no passphrase yet, or a
    /// passphrase changed on another Mac.
    public func resumePasswords() async -> Bool {
        guard isEnabled, let place = currentStore(), let key = loadKey(),
              let meta = try? await PasswordSyncStore(store: place.store).meta(), meta.opens(with: key) else { return false }
        UserDefaults.standard.set(true, forKey: passwordsKey)
        passwordsEnabled = true
        forgetPasswordFingerprint()
        await tick()
        return true
    }

    /// Stops syncing passwords. The key stays in this Mac's Keychain so turning it on again doesn't ask.
    public func disablePasswords() {
        UserDefaults.standard.set(false, forKey: passwordsKey)
        passwordsEnabled = false
        passwordStatus = nil
        forgetPasswordFingerprint()
    }

    /// The Keychain costs a few milliseconds per login, so sync never touches it on the main thread.
    private func keychain<T: Sendable>(_ work: @escaping @Sendable () -> T) async -> T {
        await Task.detached(priority: .utility, operation: work).value
    }

    /// Passwords and deletions as keys and times only, no secrets.
    private nonisolated static func light(_ logins: [SavedLogin], _ gone: [PasswordRecord]) -> [PasswordRecord] {
        logins.map { PasswordRecord(host: $0.host, username: $0.username, password: "", modified: $0.modified) } + gone
    }

    private func syncPasswords(store place: any SyncBlobStore) async {
        guard UserDefaults.standard.bool(forKey: passwordsKey), let key = loadKey() else { return }
        let store = PasswordSyncStore(store: place)
        nonisolated(unsafe) let vault = PasswordPrompter.shared.vault(for: scopeProfile)
        do {
            // The passphrase was changed on another Mac: say so instead of syncing with a key nobody else uses.
            var meta = try await store.meta()
            // A place this Mac has just moved to has no passphrase record yet: copy the one from where the passwords
            // were synced before, so the Macs that join later open the sealed files with the same passphrase.
            if meta == nil {
                for other in Backend.order where other != active {
                    guard let old = self.store(for: other), let found = try? await PasswordSyncStore(store: old).meta(), found.opens(with: key) else { continue }
                    try await store.writeMeta(found)
                    meta = found
                    break
                }
            }
            if let meta, !meta.opens(with: key) {
                passwordStatus = "Your sync passphrase was changed on another Mac. Turn Sync Passwords off and on, and enter the new one."
                return
            }
            let (others, _) = try await store.readOthers(excluding: deviceID, key: key)
            // Merge decisions need only each login's key and time, so no password is read for them.
            var light = await keychain { Self.light(vault.all(), vault.tombstones()) }
            var changed = 0
            for snapshot in others {
                let newer = PasswordMerge.changes(applying: snapshot.records, to: light)
                // A login that only carries a newer time with the very same password changes nothing. Another Mac that
                // stamps its logins afresh each round used to make every round look like news, and bounce back to it.
                let changes = await keychain {
                    let readable = Set(vault.readable().map { PasswordRecord(host: $0.host, username: $0.username, password: "", modified: $0.modified).key })
                    return PasswordMerge.worthApplying(newer, readable: readable) { r in vault.quietly { vault.password(host: r.host, username: r.username) } }
                }
                guard !changes.isEmpty else { continue }
                await keychain { vault.quietly { vault.apply(changes) } }
                changed += changes.count
                found("took passwords")
                light = await keychain { Self.light(vault.all(), vault.tombstones()) }
            }
            // What this Mac can send: logins from an older Vega wait until they are used once, so they are not
            // part of the fingerprint. Counting them made every round look unfinished and write the snapshot again.
            let sendable = await keychain { Self.light(vault.readable(), vault.tombstones()) }
            // Own snapshot (with passwords) only when a login or a deletion changed since the last write.
            let fingerprint = Self.digest(sendable)
            let stored = UserDefaults.standard.string(forKey: fingerprintKey)
            if stored == nil && !forcePasswordWrite {
                // First run with this memory: the snapshot an earlier version wrote still stands, so read nothing.
                UserDefaults.standard.set(fingerprint, forKey: fingerprintKey)
            } else if fingerprint != stored || forcePasswordWrite || passwordRetryDue {
                // Without a single dialog: a password the Keychain would ask about is left out for now, and
                // goes in once the person has used it (filled or opened it) and said Always Allow.
                let changedSinceLast = fingerprint != stored || forcePasswordWrite
                let records = await keychain { vault.quietly { vault.records() } }
                try await store.write(PasswordSnapshot(deviceID: deviceID, records: records), key: key)
                if changedSinceLast { found("sent passwords") }
                UserDefaults.standard.set(fingerprint, forKey: fingerprintKey)
                forcePasswordWrite = false
                // Some logins can stay unreadable (saved by an older build): look again now and then, not every round.
                let complete = records.filter({ !$0.deleted }).count == sendable.filter({ !$0.deleted }).count
                passwordRetryAt = complete ? nil : Date().addingTimeInterval(600)
            }
            let waiting = await keychain { vault.legacyCount() }
            passwordTotals = (light.filter { !$0.deleted }.count, waiting)
            passwordStatus = (changed > 0 ? "Passwords synced · \(changed) updated" : "Passwords synced")
                + (waiting > 0 ? ". \(waiting) saved by an older Vega stay on this Mac: macOS asks before Vega may read them. Import them again (Settings › Passwords › Import from CSV) to sync them." : "")
        } catch {
            passwordStatus = "Couldn't sync passwords: \(error.localizedDescription)"
        }
    }

    // The derived key, in this Mac's Keychain so the passphrase is asked once.
    private static let keyService = "com.vega.browser.syncKey"
    // Read from the Keychain once per launch, not on every sync round.
    @ObservationIgnored private var cachedKey: SymmetricKey?
    func loadKey() -> SymmetricKey? {
        if let cachedKey { return cachedKey }
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: keyService,
                                    kSecReturnData as String: true, kSecMatchLimit as String: kSecMatchLimitOne]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess, let data = result as? Data else { return nil }
        cachedKey = SymmetricKey(data: data)
        return cachedKey
    }
    private func saveKey(_ key: SymmetricKey) {
        deleteKey()
        cachedKey = key
        let data = key.withUnsafeBytes { Data($0) }
        SecItemAdd([kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: keyService,
                    kSecValueData as String: data, kSecAttrLabel as String: "Vega Sync",
                    kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly] as CFDictionary, nil)
    }
    private func deleteKey() {
        cachedKey = nil
        SecItemDelete([kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: keyService] as CFDictionary)
    }

    private var deviceID: UUID {
        if let text = UserDefaults.standard.string(forKey: Self.deviceKey), let id = UUID(uuidString: text) { return id }
        let id = UUID()
        UserDefaults.standard.set(id.uuidString, forKey: Self.deviceKey)
        return id
    }

    /// Called once at launch with the controller that owns the tree.
    public func start(tabs: TabsController) {
        self.tabs = tabs
        if isEnabled { begin() }
    }

    /// Starts a round now and shows its steps. The loop runs it, so two rounds never overlap.
    public func syncNow() {
        showsProgress = true
        nudge()
    }

    /// Next round now, and the pace starts over.
    private func nudge() {
        quietRounds = 0
        if let sleeper { sleeper.cancel() } else if loop == nil { Task { await tick() } } else { rerunRequested = true }
    }

    /// Something changed here: send it once it settles, without a round for every page load.
    private func treeChanged() {
        guard isEnabled else { return }
        settleTask?.cancel()
        settleTask = Task { [weak self] in
            try? await Task.sleep(for: Self.settleDelay)
            guard !Task.isCancelled, let self else { return }
            let wait = self.lastRoundEnd.addingTimeInterval(Self.minGap).timeIntervalSinceNow
            if wait > 0 { try? await Task.sleep(for: .seconds(wait)) }
            guard !Task.isCancelled else { return }
            self.nudge()
        }
    }

    /// Calls `treeChanged` whenever the tab tree changes (observation fires once, so it is set up again each time).
    private func watchTree() {
        guard isEnabled, let tabs else { return }
        withObservationTracking { _ = tabs.tree } onChange: { [weak self] in
            Task { @MainActor in
                self?.treeChanged()
                self?.watchTree()
            }
        }
    }

    /// Watches the iCloud Drive folder, so a file another Mac's change brings down starts a round within seconds.
    private func watchFolder() {
        liveConnection?.stop()
        liveConnection = nil
        if active == .server, let server = currentStore()?.store as? ServerBlobStore {
            liveConnection = server.live { [weak self] in Task { @MainActor in self?.folderChanged() } }
        }
        watcher = nil
        guard active == .iCloud, let folder = currentStore()?.store as? FolderBlobStore else { return }
        watcher = FolderWatcher(url: folder.url) { [weak self] in
            Task { @MainActor in self?.folderChanged() }
        }
    }

    /// Files changed in the sync folder. This Mac's own writes land here too; the extra round they cause finds nothing
    /// and sends nothing, so it ends there.
    private func folderChanged() {
        guard isEnabled else { return }
        watchTask?.cancel()
        watchTask = Task { [weak self] in
            // Several files arrive together; one round takes them all.
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            self?.nudge()
        }
    }

    /// Waits until the next round is due, or until `nudge` cuts it short.
    private func waitForNextRound() async {
        if rerunRequested { rerunRequested = false; return }
        let steps = min(quietRounds, 8)
        let wait = min(Self.interval * (1 << steps), slowestInterval)
        let task = Task<Void, Never> { try? await Task.sleep(for: wait) }
        sleeper = task
        await task.value
        sleeper = nil
    }

    private func begin() {
        stop(keepStatus: true)
        guard currentStore() != nil else { status = .unavailable(missingMessage); return }
        status = .syncing
        if activity == nil {
            activity = ProcessInfo.processInfo.beginActivity(options: .userInitiatedAllowingIdleSystemSleep, reason: "Vega sync")
        }
        showsProgress = true
        loop = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                await self.tick()
                await self.waitForNextRound()
            }
        }
        watchTree()
        watchFolder()
        // A change made just before the app goes to the background or quits should leave this Mac.
        let center = NotificationCenter.default
        for name in [NSApplication.didResignActiveNotification, NSApplication.willTerminateNotification] {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.writeOwn() }
            })
        }
        observers.append(center.addObserver(forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.nudge() }
        })
    }

    private func stop(keepStatus: Bool = false) {
        loop?.cancel()
        loop = nil
        sleeper?.cancel()
        sleeper = nil
        settleTask?.cancel()
        settleTask = nil
        watchTask?.cancel()
        watchTask = nil
        watcher?.stop()
        watcher = nil
        liveConnection?.stop()
        liveConnection = nil
        if !keepStatus, let activity { ProcessInfo.processInfo.endActivity(activity); self.activity = nil }
        observers.forEach(NotificationCenter.default.removeObserver)
        observers = []
        if !keepStatus { status = .off }
    }

    /// Removes everything this chain brought to this Mac: its spaces with their favorites, pinned tabs and open tabs, its
    /// passwords, and (for the first profile) the synced settings. The other Macs keep theirs. A profile always keeps a
    /// space, so a chain that held every space leaves one empty space in a fresh profile, as on a new install.
    private func eraseSyncedData() {
        guard let tabs else { return }
        let profile = scopeProfile
        let vault = KeychainVault.forProfile(profile)
        let doomed = tabs.spaces(ofProfile: profile).filter { !$0.isAgent }
        let everything = tabs.spaces(ofProfile: nil).filter { !$0.isAgent }
        var fresh: UUID?
        if doomed.count == everything.count {
            guard let space = tabs.createSpace(name: "Personal", icon: "", accentHex: "#0A84FF", after: nil, profileName: "Personal") else { return }
            fresh = tabs.tree.dataStoreID(for: space)
        }
        // Deleting a profile's last space also clears its cookies and website sign-ins.
        for space in doomed { tabs.deleteSpace(space.id) }
        tabs.history?.clearHistory(profileId: profile)
        vault.deleteAll()
        forgetSettings()
        deleteKey()
        for key in [passwordsKey, openTabsKey, fingerprintKey] { UserDefaults.standard.removeObject(forKey: key) }
        passwordsEnabled = false
        passwordStatus = nil
        otherMacsTabs = []
        devices = []
        lastWritten = nil
        lastOpenTabs = nil
        if let fresh, ProfileScope.isPrimary(profile) { ProfileScope.setPrimary(fresh) }
    }

    /// Takes another Mac out of the chain: the Macs stop reading it and it turns its own sync off at its next sync.
    public func removeDevice(_ id: UUID) {
        guard let place = currentStore() else { return }
        devices.removeAll { $0.id == id }
        Task { try? await place.store.setRemoved(id, true); await tick() }
    }

    var deviceName: String { Host.current().localizedName ?? "Mac" }

    private var seenKey: String { "fork.sync.seen" + suffix }
    private var seenSinceKey: String { "fork.sync.seenSince" + suffix }

    /// The `writtenAt` of the last snapshot read from `device`. A Mac never read before counts from when this Mac first
    /// ran this check, so deletions an older Vega held back (dated days ago) don't land all at once on an upgrade.
    private func seenUntil(_ device: UUID) -> Date {
        let defaults = UserDefaults.standard
        if let seen = (defaults.dictionary(forKey: seenKey) as? [String: Double])?[device.uuidString] {
            return Date(timeIntervalSince1970: seen)
        }
        if defaults.object(forKey: seenSinceKey) == nil { defaults.set(Date().timeIntervalSince1970, forKey: seenSinceKey) }
        return Date(timeIntervalSince1970: defaults.double(forKey: seenSinceKey))
    }

    private func markSeen(_ snapshot: SyncSnapshot) {
        var seen = UserDefaults.standard.dictionary(forKey: seenKey) as? [String: Double] ?? [:]
        seen[snapshot.deviceID.uuidString] = max(seen[snapshot.deviceID.uuidString] ?? 0, snapshot.writtenAt.timeIntervalSince1970)
        UserDefaults.standard.set(seen, forKey: seenKey)
    }

    func found(_ what: String) {
        roundFoundWork = true
        Self.logger.debug("sync round: \(what, privacy: .public)")
    }

    private func step(_ n: Int, _ label: String) {
        if showsProgress { progress = SyncProgress(step: n, label: label) }
    }

    /// Background rounds are silent and back off when they find nothing, so an idle Vega sits quiet.
    private func finishRound() {
        lastRoundEnd = Date()
        quietRounds = roundFoundWork ? 0 : quietRounds + 1
        showsProgress = false
        progress = nil
    }

    private func tick() async {
        roundFoundWork = false
        defer { finishRound() }
        guard isEnabled, let tabs else { return }
        // Automatic: go back to a better place once it may be tried again, or leave one that can no longer be used.
        if backend == .automatic, switchActive(to: resolve()) { return }
        guard let place = currentStore() else { status = .unavailable(missingMessage); return }
        let store = place.store
        let own = deviceID
        do {
            if rejoining { try await store.setRemoved(own, false); rejoining = false }
            removedIDs = await store.removedDevices()
            if removedIDs.contains(own) {
                eraseSyncedData()
                removedMessage = "Another Mac removed this Mac from the sync chain, and its synced spaces, favorites, tabs, passwords, settings, history and website sign-ins were removed from this Mac. Restart Vega to finish resetting settings. Turn on Sync my Macs to join again."
                isEnabled = false
                return
            }
            step(1, "Reading your other Macs")
            let key = passwordsEnabled ? loadKey() : nil
            let (all, pending, plainOnly) = try await SealedSync.readOthers(store, excluding: own, key: key)
            plainNeeded = key == nil || !plainOnly.subtracting(removedIDs).isEmpty
            // iCloud still bringing a file down: look again soon instead of backing off.
            if pending > 0 { found("files still downloading") }
            let snapshots = all.filter { !removedIDs.contains($0.deviceID) }
            devices = snapshots.map { SyncDevice(id: $0.deviceID, name: $0.deviceName, lastSeen: $0.writtenAt) }.sorted { $0.name < $1.name }
            step(2, "Bringing in spaces, favorites and pinned tabs")
            for snapshot in snapshots {
                let change = SyncMerge.change(applying: snapshot, to: tabs.tree, seenUntil: seenUntil(snapshot.deviceID))
                if !change.isEmpty { tabs.apply(change); found("took spaces or favorites") }
                markSeen(snapshot)
            }
            removePlaceholderIfFilled()
            step(3, "Sending this Mac's spaces")
            if try await writeOwn(store: store) { found("sent spaces") }
            await writeProfileFile(store: store)
            step(4, "Syncing passwords")
            await syncPasswords(store: store)
            step(5, "Syncing settings")
            await syncSettings(store: store, own: own, deviceName: deviceName)
            step(6, "Syncing open tabs")
            await syncOpenTabs(store: store, tabs: tabs, own: own)
            progress = nil
            summary = syncedSummary(tabs: tabs)
            // Names only: which devices have a snapshot in the store, so a failed sync can be told from an empty one.
            let present = (try? await store.list("devices").names) ?? []
            Self.logger.notice("synced via \(self.active.rawValue, privacy: .public): \(present.count) device file(s) in the store, \(snapshots.count) from other Macs")
            status = .idle(lastSync: Date(), otherMacs: snapshots.count, waitingForDownload: pending)
        } catch {
            progress = nil
            status = .failed(error.localizedDescription)
            // Automatic: rest this place for a few minutes and try the next one now.
            if backend == .automatic {
                coolingDown[active] = Date().addingTimeInterval(Self.retryAfter)
                _ = switchActive(to: resolve())
            }
        }
    }

    /// What this Mac's sync covers, as of the last round: "6 spaces · 109 favorites and pinned tabs · 157 passwords".
    private func syncedSummary(tabs: TabsController) -> String {
        let spaces = tabs.orderedSpaces.filter { !$0.isAgent && (scopeProfile == nil || tabs.profile(forSpace: $0.id)?.id == scopeProfile) }
        let saved = spaces.reduce(0) { $0 + tabs.favorites(of: $1.id).count + tabs.children(of: .pinned(spaceID: $1.id)).count }
        var parts = ["\(spaces.count) \(spaces.count == 1 ? "space" : "spaces")", "\(saved) favorites and pinned tabs"]
        if passwordsEnabled, let (total, waiting) = passwordTotals {
            parts.append(waiting > 0 ? "\(total - waiting) of \(total) passwords" : "\(total) passwords")
        }
        return parts.joined(separator: " · ")
    }

    /// Writes this Mac's open tabs (when shared, and only when they changed) and reads the others'.
    private func syncOpenTabs(store: any SyncBlobStore, tabs: TabsController, own: UUID) async {
        do {
            // The passwords key seals the list, so full addresses can travel. Without it the list is plain text and cleaned.
            let key = loadKey()
            let entries = sharesOpenTabs ? ownOpenTabs(in: tabs, profile: scopeProfile, keepFullAddresses: key != nil) : []
            if entries != lastOpenTabs {
                try await store.writeOpenTabs(OpenTabsSnapshot(deviceID: own, deviceName: deviceName, writtenAt: Date(), tabs: entries), key: key)
                lastOpenTabs = entries
                found("sent open tabs")
            }
            let others = try await store.readOtherOpenTabs(excluding: own, key: key).filter { !removedIDs.contains($0.deviceID) }
            // The time a Mac wrote its list is not news; only a change in its tabs is.
            let listed = { (list: [OpenTabsSnapshot]) in list.map { [$0.deviceID.uuidString, $0.deviceName, $0.tabs.description] }.sorted { $0[0] < $1[0] } }
            if listed(others) != listed(otherMacsTabs) { found("other Macs' open tabs changed") }
            otherMacsTabs = others
        } catch {
            Self.logger.error("open tabs sync failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - A profile brought from another Mac

    /// A profile added from an account on another Mac starts with one empty space (a profile needs a space to exist).
    /// That space stays on this Mac, out of the files, and goes once the profile's real spaces have arrived.
    public static func placeholderKey(_ profileID: UUID) -> String { "fork.profile.placeholder.\(profileID.uuidString)" }
    private var placeholderID: UUID? {
        scopeProfile.flatMap { UserDefaults.standard.string(forKey: Self.placeholderKey($0)) }.flatMap(UUID.init(uuidString:))
    }

    private func removePlaceholderIfFilled() {
        guard let tabs, let placeholder = placeholderID, let profile = scopeProfile else { return }
        let others = tabs.spaces(ofProfile: profile).filter { $0.id != placeholder && !$0.isAgent }
        guard !others.isEmpty else { return }
        if tabs.tabCount(inSpace: placeholder) == 0 { tabs.deleteSpace(placeholder) }
        UserDefaults.standard.removeObject(forKey: Self.placeholderKey(profile))
    }

    @ObservationIgnored private var lastIdentity: ProfileIdentity?

    /// The profile the sync place holds (its `profile.json`), if any: used by a fresh Mac to take it as its first.
    func remoteProfile() async -> ProfileIdentity? {
        guard let place = currentStore() else { return nil }
        return ProfileIdentity.decode(try? await place.store.get(ProfileIdentity.path))
    }

    /// Says in the account's folder which profile this is, so another Mac can bring the same one.
    private func writeProfileFile(store: any SyncBlobStore) async {
        guard let tabs, let id = scopeProfile, let name = tabs.profiles.first(where: { $0.id == id })?.name else { return }
        let identity = ProfileIdentity(id: id, name: name)
        guard identity != lastIdentity else { return }
        if (try? await store.put(ProfileIdentity.path, identity.encoded())) != nil { lastIdentity = identity }
    }

    private func writeOwn() {
        guard isEnabled, let place = currentStore() else { return }
        Task { try? await writeOwn(store: place.store) }
    }

    /// Writes only when something other than the timestamp changed.
    @discardableResult
    private func writeOwn(store: any SyncBlobStore) async throws -> Bool {
        guard let tabs else { return false }
        // Built and compared off the main thread: the tree is a value, so this works on a copy.
        let tree = tabs.tree, id = deviceID, name = deviceName, profile = scopeProfile, mirror = mirrorsTabs
        let placeholder = placeholderID, last = lastWritten
        let built: SyncSnapshot? = await Task.detached(priority: .utility) {
            var snapshot = SyncMerge.snapshot(of: tree, deviceID: id, deviceName: name, profile: profile, includeTabs: mirror)
            if let placeholder {
                snapshot.spaces.removeAll { $0.id == placeholder }
                snapshot.items.removeAll { tree.spaceID(of: $0.id) == placeholder }
            }
            if let last, last.spaces == snapshot.spaces, last.items == snapshot.items { return nil }
            return snapshot
        }.value
        let key = passwordsEnabled ? loadKey() : nil
        let mode = (sealed: key != nil, plain: key == nil || plainNeeded)
        // The same snapshot written the same way is not news; a new way of writing it is.
        let snapshot: SyncSnapshot
        if let built { snapshot = built } else if let last, let previous = lastWrittenMode, previous != mode { snapshot = last } else { return false }
        try await SealedSync.write(snapshot, to: store, key: key, plainNeeded: mode.plain)
        lastWritten = snapshot
        lastWrittenMode = mode
        return true
    }
}

/// A Mac in the sync chain, as listed in Settings.
/// One step of a sync round, for the progress bar in Settings.
public struct SyncProgress: Equatable, Sendable {
    public static let steps = 6
    public let step: Int
    public let label: String
}

public struct SyncDevice: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let name: String
    public let lastSeen: Date
}
