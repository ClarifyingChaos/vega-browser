// Licensed under GPL-3.0. See LICENSE.
//
//  SettingsSnapshot.swift
//  NookWeb
//
//  FORK: which of the person's settings travel between their Macs, and how they are written and read. The sync
//  itself is in SyncSettings.swift.
//

import Foundation

public enum SettingsSnapshot {
    /// Keys that are about the person, by prefix or exact name.
    static let included: [String] = ["settings.", "keyboard.shortcuts", "siteZoomLevels", "fork.passwords.autofill",
                                     "fork.passwords.offerToSave", "fork.passwords.never"]
    /// Inside `settings.`, what belongs to this Mac or this moment.
    static let excluded: Set<String> = ["settings.didFinishOnboarding", "settings.lastSeenVersion", "settings.pinnedExtensionIDs",
                                        "settings.pinnedExtensionIDsMigrated", "settings.debugToggleUpdateNotification"]

    public static func isSynced(_ key: String) -> Bool {
        !excluded.contains(key) && included.contains { key == $0 || (($0.hasSuffix(".") || $0 == "siteZoomLevels") && key.hasPrefix($0)) }
    }

    /// The synced settings now in `defaults`.
    public static func current(_ defaults: UserDefaults = .standard) -> [String: Any] {
        defaults.dictionaryRepresentation().filter { isSynced($0.key) }
    }

    /// A short fingerprint of the values, to tell whether anything changed since the last look.
    public static func digest(_ values: [String: Any]) -> String {
        var hash: UInt64 = 1469598103934665603
        // Folded key by key in sorted order, so the same settings always give the same fingerprint.
        for key in values.keys.sorted() {
            let one = (try? PropertyListSerialization.data(fromPropertyList: [key: values[key] as Any], format: .binary, options: 0)) ?? Data()
            for byte in one { hash = (hash ^ UInt64(byte)) &* 1099511628211 }
        }
        return String(hash, radix: 16)
    }

    public static func encode(values: [String: Any], writtenAt: Date, device: String) -> Data? {
        try? PropertyListSerialization.data(fromPropertyList: ["writtenAt": writtenAt, "device": device, "values": values], format: .xml, options: 0)
    }

    public struct File {
        public var writtenAt: Date
        public var device: String
        public var values: [String: Any]
    }

    public static func decode(_ data: Data?) -> File? {
        guard let data, let plist = (try? PropertyListSerialization.propertyList(from: data, format: nil)) as? [String: Any],
              let at = plist["writtenAt"] as? Date, let values = plist["values"] as? [String: Any] else { return nil }
        return File(writtenAt: at, device: plist["device"] as? String ?? "another Mac", values: values.filter { isSynced($0.key) })
    }

    /// Forgets every synced setting, so the Mac falls back to Vega's defaults.
    public static func reset(_ defaults: UserDefaults = .standard) {
        for key in current(defaults).keys { defaults.removeObject(forKey: key) }
    }

    /// Writes `values` into `defaults`, and returns how many differed from what was there.
    @discardableResult
    public static func apply(_ values: [String: Any], to defaults: UserDefaults = .standard) -> Int {
        var changed = 0
        for (key, value) in values where isSynced(key) {
            if let old = defaults.object(forKey: key), (old as AnyObject).isEqual(value) { continue }
            defaults.set(value, forKey: key)
            changed += 1
        }
        return changed
    }
}
