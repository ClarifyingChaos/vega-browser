// Licensed under GPL-3.0. See LICENSE.
//
//  SyncSettings.swift
//  NookWeb
//
//  FORK: the person's settings travel with their first profile's account: search engine, tab behaviour, appearance,
//  keyboard shortcuts, privacy switches, password switches. Not synced: things that belong to one Mac or one window
//  (window and sidebar sizes, which extensions are pinned, onboarding, what sync itself remembers). Each Mac writes
//  its own file; the newest one wins, and a Mac that never synced settings before takes the other Mac's, so a new Mac
//  starts the way the first one is set up. They apply the next time Vega opens, because the app reads them at launch.
//

import Foundation
import NookTabsCore

extension SyncCoordinator {
    static var settingsAppliedKey: String { "fork.sync.settingsAppliedAt" }
    static var settingsDigestKey: String { "fork.sync.settingsDigest" }
    static var settingsChangedKey: String { "fork.sync.settingsChangedAt" }

    /// A Mac taken out of the chain forgets the settings it took, and what it remembered about syncing them.
    func forgetSettings() {
        guard profileID == nil || ProfileScope.isPrimary(profileID) else { return }
        SettingsSnapshot.reset()
        for key in [Self.settingsAppliedKey, Self.settingsDigestKey, Self.settingsChangedKey] { UserDefaults.standard.removeObject(forKey: key) }
    }

    /// Called every tick for the first profile's account only.
    func syncSettings(store: any SyncBlobStore, own: UUID, deviceName: String) async {
        guard profileID == nil || ProfileScope.isPrimary(profileID) else { return }
        let defaults = UserDefaults.standard
        // Reading every setting and fingerprinting it is the slow part of a round; UserDefaults is safe off the main thread.
        let read = await Task.detached(priority: .utility) { () -> SettingsRead in
            let values = SettingsSnapshot.current(.standard)
            return SettingsRead(values: values, digest: SettingsSnapshot.digest(values))
        }.value
        let values = read.values, digest = read.digest
        let now = Date()
        // When this Mac's settings last changed: noticed here, at the next tick after the change.
        if defaults.string(forKey: Self.settingsDigestKey) != digest {
            defaults.set(digest, forKey: Self.settingsDigestKey)
            defaults.set(now, forKey: Self.settingsChangedKey)
        }
        let changedAt = defaults.object(forKey: Self.settingsChangedKey) as? Date ?? now
        let neverSynced = defaults.object(forKey: Self.settingsAppliedKey) == nil

        do {
            // Sealed copies (".enc") open with the sync passphrase's key; plain ones (".plist") are read as before.
            let key = loadKey()
            let names = try await store.list("settings").names.filter { name in
                (name.hasSuffix(".plist") || (key != nil && name.hasSuffix(".enc"))) && !name.hasPrefix(own.uuidString) && !removedIDs.contains { name.hasPrefix($0.uuidString) }
            }
            var newest: SettingsSnapshot.File?
            for name in names {
                guard var data = try await store.get("settings/\(name)") else { continue }
                if name.hasSuffix(".enc") {
                    guard let key, let opened = PasswordCrypto.open(data, with: key) else { continue }
                    data = opened
                }
                if let file = SettingsSnapshot.decode(data), !file.values.isEmpty, file.writtenAt > (newest?.writtenAt ?? .distantPast) { newest = file }
            }
            let appliedAt = defaults.object(forKey: Self.settingsAppliedKey) as? Date ?? .distantPast
            // Take the other Mac's when this Mac never synced settings, or theirs is newer than both the last one taken
            // and anything changed here since.
            if let newest, neverSynced || (newest.writtenAt > appliedAt && newest.writtenAt > changedAt) {
                found("took settings")
                let count = SettingsSnapshot.apply(newest.values, to: defaults)
                defaults.set(newest.writtenAt, forKey: Self.settingsAppliedKey)
                defaults.set(SettingsSnapshot.digest(SettingsSnapshot.current(defaults)), forKey: Self.settingsDigestKey)
                if count > 0 { settingsStatus = "Settings from \(newest.device) were applied. Restart Vega to use them." }
                return
            }
            // Ours: written when it changed, or the first time (so the other Macs have something to take).
            if neverSynced || changedAt > appliedAt, let data = SettingsSnapshot.encode(values: values, writtenAt: changedAt, device: deviceName) {
                if let key {
                    try await store.put("settings/\(own.uuidString).enc", PasswordCrypto.seal(data, with: key))
                    // The plain copy only while a Mac reads nothing else; otherwise an empty one, which changes nothing.
                    let plain = plainNeeded ? data : SettingsSnapshot.encode(values: [:], writtenAt: changedAt, device: deviceName)
                    if let plain { try await store.put("settings/\(own.uuidString).plist", plain) }
                } else {
                    try await store.put("settings/\(own.uuidString).plist", data)
                }
                found("sent settings")
                defaults.set(changedAt, forKey: Self.settingsAppliedKey)
            }
        } catch {
            // Settings are not worth a failed-sync banner: the next tick tries again.
        }
    }
}

/// Settings as read off the main thread. Property-list values only, read once and not shared after.
private struct SettingsRead: @unchecked Sendable {
    let values: [String: Any]
    let digest: String
}
