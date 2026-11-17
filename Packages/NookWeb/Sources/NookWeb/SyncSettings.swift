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
    private static var settingsAppliedKey: String { "fork.sync.settingsAppliedAt" }
    private static var settingsDigestKey: String { "fork.sync.settingsDigest" }
    private static var settingsChangedKey: String { "fork.sync.settingsChangedAt" }

    /// Called every tick for the first profile's account only.
    func syncSettings(store: any SyncBlobStore, own: UUID, deviceName: String) async {
        guard profileID == nil || ProfileScope.isPrimary(profileID) else { return }
        let defaults = UserDefaults.standard
        let values = SettingsSnapshot.current(defaults)
        let digest = SettingsSnapshot.digest(values)
        let now = Date()
        // When this Mac's settings last changed: noticed here, at the next tick after the change.
        if defaults.string(forKey: Self.settingsDigestKey) != digest {
            defaults.set(digest, forKey: Self.settingsDigestKey)
            defaults.set(now, forKey: Self.settingsChangedKey)
        }
        let changedAt = defaults.object(forKey: Self.settingsChangedKey) as? Date ?? now
        let neverSynced = defaults.object(forKey: Self.settingsAppliedKey) == nil

        do {
            let names = try await store.list("settings").names.filter { name in name.hasSuffix(".plist") && !name.hasPrefix(own.uuidString) && !removedIDs.contains { name.hasPrefix($0.uuidString) } }
            var newest: SettingsSnapshot.File?
            for name in names {
                if let file = SettingsSnapshot.decode(try await store.get("settings/\(name)")), file.writtenAt > (newest?.writtenAt ?? .distantPast) { newest = file }
            }
            let appliedAt = defaults.object(forKey: Self.settingsAppliedKey) as? Date ?? .distantPast
            // Take the other Mac's when this Mac never synced settings, or theirs is newer than both the last one taken
            // and anything changed here since.
            if let newest, neverSynced || (newest.writtenAt > appliedAt && newest.writtenAt > changedAt) {
                let count = SettingsSnapshot.apply(newest.values, to: defaults)
                defaults.set(newest.writtenAt, forKey: Self.settingsAppliedKey)
                defaults.set(SettingsSnapshot.digest(SettingsSnapshot.current(defaults)), forKey: Self.settingsDigestKey)
                if count > 0 { settingsStatus = "Settings from \(newest.device) were applied. Restart Vega to use them." }
                return
            }
            // Ours: written when it changed, or the first time (so the other Macs have something to take).
            if neverSynced || changedAt > appliedAt, let data = SettingsSnapshot.encode(values: values, writtenAt: changedAt, device: deviceName) {
                try await store.put("settings/\(own.uuidString).plist", data)
                defaults.set(changedAt, forKey: Self.settingsAppliedKey)
            }
        } catch {
            // Settings are not worth a failed-sync banner: the next tick tries again.
        }
    }
}
