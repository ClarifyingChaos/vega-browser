// Licensed under GPL-3.0. See LICENSE.
//
//  SyncCoordinator.swift
//  NookWeb
//
//  FORK: runs `SyncMerge` and `SyncFolder` for the app. Off until the person turns it on. Every
//  tick it applies what other Macs wrote, then writes this Mac's snapshot if it changed.
//  shortcut: polls every 20 s instead of watching the folder; local edits reach the other Mac
//  within one tick plus iCloud's own delay. Upgrade to a file-system event watcher if that lags.
//

import AppKit
import CryptoKit
import Foundation
import NookTabsCore
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
        backend = Backend(rawValue: UserDefaults.standard.string(forKey: "fork.sync.backend" + suffix) ?? "") ?? .iCloud
        sharesOpenTabs = UserDefaults.standard.bool(forKey: "fork.sync.openTabs" + suffix)
        mirrorsTabs = UserDefaults.standard.object(forKey: "fork.sync.mirrorTabs" + suffix) as? Bool ?? true
        passwordsEnabled = UserDefaults.standard.bool(forKey: "fork.sync.passwords" + suffix)
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
        case iCloud, google
        public var id: String { rawValue }
        public var title: String { self == .iCloud ? "iCloud Drive" : "Google account" }
    }

    private static let logger = Logger(subsystem: "com.vega.browser", category: "sync")
    private static let deviceKey = "fork.sync.deviceID"
    private static let interval: Duration = .seconds(20)

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
    /// Keeps macOS from slowing the sync loop (App Nap) while Vega sits hidden or minimised: a Mac whose Vega is in
    /// the background must still send and take changes within a round or two.
    @ObservationIgnored private var activity: NSObjectProtocol?
    @ObservationIgnored private var lastWritten: SyncSnapshot?
    @ObservationIgnored private var observers: [Any] = []

    public var backend: Backend {
        didSet {
            guard backend != oldValue else { return }
            UserDefaults.standard.set(backend.rawValue, forKey: backendKey)
            // Another place is another set of files: start each side from scratch.
            lastWritten = nil
            forgetPasswordFingerprint()
            if isEnabled { begin() }
        }
    }

    /// Where this Mac syncs right now, or why it can't.
    func currentStore() -> (store: any SyncBlobStore, missing: String?)? {
        switch backend {
        case .iCloud:
            // A scripted run points two copies of Vega at one folder, standing in for two Macs.
            let override = UserDefaults.standard.string(forKey: "fork.sync.testFolder").map { URL(fileURLWithPath: $0, isDirectory: true) }
            guard var url = override ?? FolderBlobStore.iCloudDrive() else { return nil }
            // One iCloud account holds every profile's files: each other profile gets its own folder.
            if !suffix.isEmpty, let profileID { url.appendPathComponent("Profiles/\(profileID.uuidString)", isDirectory: true) }
            return (FolderBlobStore(url: url), nil)
        case .google:
            guard let store = GoogleAccount.forProfile(profileID).store() else { return nil }
            return (store, nil)
        }
    }

    private var missingMessage: String {
        backend == .iCloud ? "Turn on iCloud Drive in System Settings › Apple Account › iCloud, then try again."
                           : "Sign in with Google to sync."
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
        return (try? await PasswordSyncStore(store: place.store).meta()).map { $0 != nil }
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

    private func syncPasswords(store place: any SyncBlobStore) async {
        guard UserDefaults.standard.bool(forKey: passwordsKey), let key = loadKey() else { return }
        let store = PasswordSyncStore(store: place)
        let vault = PasswordPrompter.shared.vault(for: scopeProfile)
        do {
            // The passphrase was changed on another Mac: say so instead of syncing with a key nobody else uses.
            if let meta = try await store.meta(), !meta.opens(with: key) {
                passwordStatus = "Your sync passphrase was changed on another Mac. Turn Sync Passwords off and on, and enter the new one."
                return
            }
            let (others, _) = try await store.readOthers(excluding: deviceID, key: key)
            // Merge decisions need only each login's key and time, so no password is read for them.
            var light = vault.all().map { PasswordRecord(host: $0.host, username: $0.username, password: "", modified: $0.modified) } + vault.tombstones()
            var changed = 0
            for snapshot in others {
                let changes = PasswordMerge.changes(applying: snapshot.records, to: light)
                if !changes.isEmpty { vault.quietly { vault.apply(changes) }; changed += changes.count }
                light = vault.all().map { PasswordRecord(host: $0.host, username: $0.username, password: "", modified: $0.modified) } + vault.tombstones()
            }
            // Own snapshot (with passwords) only when a login or a deletion changed since the last write.
            let fingerprint = Self.digest(light)
            let stored = UserDefaults.standard.string(forKey: fingerprintKey)
            if stored == nil && !forcePasswordWrite {
                // First run with this memory: the snapshot an earlier version wrote still stands, so read nothing.
                UserDefaults.standard.set(fingerprint, forKey: fingerprintKey)
            } else if fingerprint != stored || forcePasswordWrite {
                // Without a single dialog: a password the Keychain would ask about is left out for now, and
                // goes in once the person has used it (filled or opened it) and said Always Allow.
                let records = vault.quietly { vault.records() }
                try await store.write(PasswordSnapshot(deviceID: deviceID, records: records), key: key)
                if records.filter({ !$0.deleted }).count == light.filter({ !$0.deleted }).count {
                    UserDefaults.standard.set(fingerprint, forKey: fingerprintKey)
                    forcePasswordWrite = false
                } else {
                    forcePasswordWrite = true
                }
            }
            passwordStatus = changed > 0 ? "Passwords synced · \(changed) updated" : "Passwords synced"
        } catch {
            passwordStatus = "Couldn't sync passwords: \(error.localizedDescription)"
        }
    }

    // The derived key, in this Mac's Keychain so the passphrase is asked once.
    private static let keyService = "com.vega.browser.syncKey"
    // Read from the Keychain once per launch, not on every sync round.
    @ObservationIgnored private var cachedKey: SymmetricKey?
    private func loadKey() -> SymmetricKey? {
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

    public func syncNow() { Task { await tick() } }

    private func begin() {
        stop(keepStatus: true)
        guard currentStore() != nil else { status = .unavailable(missingMessage); return }
        status = .syncing
        if activity == nil {
            activity = ProcessInfo.processInfo.beginActivity(options: .userInitiatedAllowingIdleSystemSleep, reason: "Vega sync")
        }
        loop = Task { [weak self] in
            while !Task.isCancelled {
                await self?.tick()
                try? await Task.sleep(for: Self.interval)
            }
        }
        // A change made just before the app goes to the background or quits should leave this Mac.
        let center = NotificationCenter.default
        for name in [NSApplication.didResignActiveNotification, NSApplication.willTerminateNotification] {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.writeOwn() }
            })
        }
        observers.append(center.addObserver(forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.syncNow() }
        })
    }

    private func stop(keepStatus: Bool = false) {
        loop?.cancel()
        loop = nil
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

    private func tick() async {
        guard isEnabled, let tabs else { return }
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
            let (all, pending) = try await store.readOtherSnapshots(excluding: own)
            let snapshots = all.filter { !removedIDs.contains($0.deviceID) }
            devices = snapshots.map { SyncDevice(id: $0.deviceID, name: $0.deviceName, lastSeen: $0.writtenAt) }.sorted { $0.name < $1.name }
            for snapshot in snapshots {
                let change = SyncMerge.change(applying: snapshot, to: tabs.tree, seenUntil: seenUntil(snapshot.deviceID))
                if !change.isEmpty { tabs.apply(change) }
                markSeen(snapshot)
            }
            removePlaceholderIfFilled()
            try await writeOwn(store: store)
            await writeProfileFile(store: store)
            await syncPasswords(store: store)
            await syncSettings(store: store, own: own, deviceName: deviceName)
            await syncOpenTabs(store: store, tabs: tabs, own: own)
            // Names only: which devices have a snapshot in the store, so a failed sync can be told from an empty one.
            let present = (try? await store.list("devices").names) ?? []
            Self.logger.notice("synced via \(self.backend.rawValue, privacy: .public): \(present.count) device file(s) in the store, \(snapshots.count) from other Macs")
            status = .idle(lastSync: Date(), otherMacs: snapshots.count, waitingForDownload: pending)
        } catch {
            status = .failed(error.localizedDescription)
        }
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
            }
            otherMacsTabs = try await store.readOtherOpenTabs(excluding: own, key: key).filter { !removedIDs.contains($0.deviceID) }
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
    private func writeOwn(store: any SyncBlobStore) async throws {
        guard let tabs else { return }
        var snapshot = SyncMerge.snapshot(of: tabs.tree, deviceID: deviceID, deviceName: deviceName, profile: scopeProfile, includeTabs: mirrorsTabs)
        if let placeholder = placeholderID {
            snapshot.spaces.removeAll { $0.id == placeholder }
            snapshot.items.removeAll { tabs.tree.spaceID(of: $0.id) == placeholder }
        }
        if let last = lastWritten, last.spaces == snapshot.spaces, last.items == snapshot.items { return }
        try await store.writeSnapshot(snapshot)
        lastWritten = snapshot
    }
}

/// A Mac in the sync chain, as listed in Settings.
public struct SyncDevice: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let name: String
    public let lastSeen: Date
}
