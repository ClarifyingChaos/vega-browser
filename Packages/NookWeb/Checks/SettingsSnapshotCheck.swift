// Licensed under GPL-3.0. See LICENSE.
//
//  SettingsSnapshotCheck.swift
//  Nook
//
//  What travels between Macs: the person's settings, not one Mac's windows, extensions or sync state; values
//  survive the file; the same settings always fingerprint alike; applying only writes what differs.
//
//    swiftc Packages/NookWeb/Sources/NookWeb/SettingsSnapshot.swift Packages/NookWeb/Checks/SettingsSnapshotCheck.swift -o /tmp/settings-snapshot-check && /tmp/settings-snapshot-check

import Foundation

@main
struct SettingsSnapshotCheck {
    static func main() {
        for key in ["settings.searchEngineId", "settings.tabManagementMode", "keyboard.shortcuts", "fork.passwords.autofill", "fork.passwords.never"] {
            precondition(SettingsSnapshot.isSynced(key), "\(key) is the person's")
        }
        for key in ["settings.didFinishOnboarding", "settings.pinnedExtensionIDs", "settings.lastSeenVersion", "sidebarWidth.abc", "fork.sync.enabled",
                    "fork.sync.passwords", "fork.passwords.primaryProfile", "fork.passwords.tombstones", "fork.google.email", "NSWindow Frame x"] {
            precondition(!SettingsSnapshot.isSynced(key), "\(key) stays on this Mac")
        }

        let suite = UserDefaults(suiteName: "settings-snapshot-check-\(UUID().uuidString)")!
        suite.set("duckduckgo", forKey: "settings.searchEngineId")
        suite.set(true, forKey: "settings.blockScriptedPopups")
        suite.set(Data([1, 2, 3]), forKey: "settings.siteRoutingRules")
        suite.set(["a.com", "b.com"], forKey: "fork.passwords.never")
        suite.set(300.0, forKey: "sidebarWidth.x")
        suite.set(true, forKey: "fork.sync.enabled")
        let values = SettingsSnapshot.current(suite)
        precondition(Set(values.keys) == ["settings.searchEngineId", "settings.blockScriptedPopups", "settings.siteRoutingRules", "fork.passwords.never"],
                     "only the person's settings are taken: \(values.keys.sorted())")

        let digest = SettingsSnapshot.digest(values)
        precondition(digest == SettingsSnapshot.digest(SettingsSnapshot.current(suite)), "the same settings fingerprint alike")
        suite.set("google", forKey: "settings.searchEngineId")
        precondition(digest != SettingsSnapshot.digest(SettingsSnapshot.current(suite)), "a changed setting changes it")

        let when = Date(timeIntervalSince1970: 1_800_000_000)
        let file = SettingsSnapshot.decode(SettingsSnapshot.encode(values: values, writtenAt: when, device: "Studio"))
        precondition(file?.writtenAt == when && file?.device == "Studio", "the file keeps who and when")
        precondition((file?.values["fork.passwords.never"] as? [String]) == ["a.com", "b.com"] && (file?.values["settings.siteRoutingRules"] as? Data) == Data([1, 2, 3]),
                     "strings, lists and data survive")
        precondition(SettingsSnapshot.decode(nil) == nil && SettingsSnapshot.decode(Data("junk".utf8)) == nil, "no file or a bad one is no settings")

        let other = UserDefaults(suiteName: "settings-snapshot-check-\(UUID().uuidString)")!
        other.set("kept", forKey: "sidebarWidth.x")
        let count = SettingsSnapshot.apply(file!.values.merging(["fork.sync.enabled": true, "settings.didFinishOnboarding": false]) { a, _ in a }, to: other)
        precondition(count == 4, "four settings written, the Mac-only ones left out: \(count)")
        precondition(other.string(forKey: "settings.searchEngineId") == "duckduckgo" && other.string(forKey: "sidebarWidth.x") == "kept", "applied, and this Mac's own layout untouched")
        precondition(other.object(forKey: "fork.sync.enabled") == nil && other.object(forKey: "settings.didFinishOnboarding") == nil, "Mac-only keys never arrive")
        precondition(SettingsSnapshot.apply(file!.values, to: other) == 0, "applying the same again changes nothing")
        print("SettingsSnapshotCheck ok")
    }
}
