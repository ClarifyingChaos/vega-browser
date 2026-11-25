// Licensed under GPL-3.0. See LICENSE.
//
//  RenameMigration.swift
//  Vega
//
//  Vega's saved names once carried the name of the project it was forked from: settings keys, the extension
//  controller's id, two Keychain services and the compiled ad-block rule lists. This moves each to its Vega name
//  once, before anything reads it, so no setting, saved AI key, saved site password or installed extension is lost.
//  Runs from Main.swift right after LegacyDataMigration, which may copy old keys in.
//

import Foundation
import OSLog
import Security
import WebKit

enum RenameMigration {
    private static let doneKey = "fork.renameMigration.v1"
    private static let log = Logger(subsystem: "com.vega.browser", category: "Migration")
    private static let oldWord = "nook"

    /// The Keychain services whose names changed: old, new.
    private static let keychainServices = [("com.nook.aiProvider", "com.vega.aiProvider"),
                                           ("com.nook.basicAuth", "com.vega.basicAuth")]

    static func renamed(_ name: String) -> String {
        name.replacingOccurrences(of: "NOOK", with: "VEGA").replacingOccurrences(of: "Nook", with: "Vega")
            .replacingOccurrences(of: oldWord, with: "vega")
    }

    static func run(defaults: UserDefaults = .standard) {
        if defaults.bool(forKey: doneKey) { return }

        // Settings: every saved key that carries the old word moves to its new name, unless the new one is already set.
        var moved = 0
        for (key, value) in defaults.dictionaryRepresentation() where key.range(of: oldWord, options: .caseInsensitive) != nil {
            let new = renamed(key)
            if defaults.object(forKey: new) == nil { defaults.set(value, forKey: new); moved += 1 }
            defaults.removeObject(forKey: key)
        }

        // Keychain: the same items under a new service name. A duplicate means it already moved. A test run
        // (fork.keychain.testPrefix set) leaves the real Keychain alone.
        let testing = defaults.string(forKey: "fork.keychain.testPrefix") != nil
        for (old, new) in keychainServices where !testing {
            let status = SecItemUpdate([kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: old] as CFDictionary,
                                       [kSecAttrService as String: new] as CFDictionary)
            if status != errSecSuccess && status != errSecItemNotFound && status != errSecDuplicateItem {
                log.error("Keychain service move failed: \(status)")
            }
        }

        // Compiled ad-block lists under their old names are only disk: WebKit rebuilds them under the new names.
        DispatchQueue.main.async {
            guard let store = WKContentRuleListStore.default() else { return }
            store.getAvailableContentRuleListIdentifiers { ids in
                for id in ids ?? [] where id.range(of: oldWord, options: .caseInsensitive) != nil {
                    DispatchQueue.main.async { store.removeContentRuleList(forIdentifier: id) { _ in } }
                }
            }
        }

        defaults.set(true, forKey: doneKey)
        log.notice("Moved \(moved) saved settings to their new names")
    }
}
