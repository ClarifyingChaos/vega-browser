// Licensed under GPL-3.0. See LICENSE.
//
//  KeychainVault.swift
//  NookWeb
//
//  FORK: Vega's saved logins live in the login Keychain as internet passwords: encrypted by the
//  system, not readable by other apps without a prompt. Listing reads attributes only, so it
//  never asks for access; reading a password does.
//

import Foundation
import Security

public final class KeychainVault: PasswordVault {
    /// The first profile's vault: it keeps the passwords saved before profiles had their own.
    public static let shared = KeychainVault(domain: KeychainVault.domain, readsLegacy: true)
    /// Marks Vega's items among everything else in the Keychain. The Keychain ties each item to the app build that
    /// wrote it, and builds before signing was stable each had their own identity, so their items ask before every
    /// read. New items go under `.v2`, written by the stable identity, and never ask; an old item is copied over the
    /// first time it is read (or when the same login is saved or imported again) and is not read again.
    private static let domain = "com.vega.browser.passwords.v2"
    private static let legacyDomain = "com.vega.browser.passwords"
    /// Old items the person deleted. An old item cannot be removed without a dialog, so it is hidden instead.
    private static let hiddenKey = "fork.passwords.hiddenLegacy"

    /// This vault's items: the first profile keeps `.v2`, every other profile gets `.v2.<profile id>`.
    private let domain: String
    /// Only the first profile has passwords from before `.v2` to move over.
    private let readsLegacy: Bool

    private init(domain: String, readsLegacy: Bool) {
        self.domain = domain
        self.readsLegacy = readsLegacy
    }

    // FORK: each profile keeps its own passwords, as in Chrome.
    private static let primaryKey = ProfileScope.primaryKey
    nonisolated(unsafe) private static var vaults: [UUID: KeychainVault] = [:]

    /// The profile that owns the passwords saved before profiles had their own. Set once, on the first launch
    /// that has profiles; later calls do nothing.
    public static func claimPrimary(_ profileID: UUID) {
        if UserDefaults.standard.string(forKey: primaryKey) == nil {
            UserDefaults.standard.set(profileID.uuidString, forKey: primaryKey)
        }
    }

    /// The vault of one profile: `shared` for the first profile (or when the profile is unknown), its own for any other.
    public static func forProfile(_ profileID: UUID?) -> KeychainVault {
        guard let profileID, UserDefaults.standard.string(forKey: primaryKey).flatMap(UUID.init(uuidString:)) != profileID,
              UserDefaults.standard.string(forKey: primaryKey) != nil else { return shared }
        if let vault = vaults[profileID] { return vault }
        let vault = KeychainVault(domain: "\(Self.domain).\(profileID.uuidString)", readsLegacy: false)
        vaults[profileID] = vault
        return vault
    }

    private func base(host: String? = nil, username: String? = nil, domain: String? = nil) -> [String: Any] {
        let domain = domain ?? self.domain
        var query: [String: Any] = [
            kSecClass as String: kSecClassInternetPassword,
            kSecAttrSecurityDomain as String: domain,
        ]
        if let host { query[kSecAttrServer as String] = PasswordHosts.normalized(host) }
        if let username { query[kSecAttrAccount as String] = username }
        return query
    }

    /// When a login last changed, kept in the item itself so a login written from another Mac keeps
    /// that Mac's time; the Keychain's own modification date would be "now" and bounce between Macs.
    private static func encode(_ date: Date) -> Data { Data(String(date.timeIntervalSince1970).utf8) }
    private static func decode(_ data: Data?) -> Date? {
        data.flatMap { String(data: $0, encoding: .utf8) }.flatMap(Double.init).map(Date.init(timeIntervalSince1970:))
    }

    @available(macOS, deprecated: 10.10, message: "the only switch for the file Keychain's access prompts")
    public func quietly<T>(_ body: () -> T) -> T {
        SecKeychainSetUserInteractionAllowed(false)
        defer { SecKeychainSetUserInteractionAllowed(true) }
        return body()
    }

    public func all() -> [SavedLogin] {
        let current = items(in: domain)
        guard readsLegacy else { return current }
        let have = Set(current.map(\.id))
        let hidden = Set(UserDefaults.standard.stringArray(forKey: Self.hiddenKey) ?? [])
        return current + items(in: Self.legacyDomain).filter { !have.contains($0.id) && !hidden.contains($0.id) }
    }

    private func items(in domain: String) -> [SavedLogin] {
        var query = base(domain: domain)
        query[kSecReturnAttributes as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitAll
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let items = result as? [[String: Any]] else { return [] }
        return items.compactMap { item in
            guard let host = item[kSecAttrServer as String] as? String,
                  let user = item[kSecAttrAccount as String] as? String else { return nil }
            let modified = Self.decode(item[kSecAttrGeneric as String] as? Data)
                ?? item[kSecAttrModificationDate as String] as? Date ?? .distantPast
            return SavedLogin(host: host, username: user, modified: modified)
        }
    }

    public func password(host: String, username: String) -> String? {
        if let secret = read(base(host: host, username: username)) { return secret }
        // An old item: this read may ask once. Copy it under the stable identity so it never asks again.
        guard readsLegacy, let login = items(in: Self.legacyDomain).first(where: { $0.host == PasswordHosts.normalized(host) && $0.username == username }),
              let secret = read(base(host: host, username: username, domain: Self.legacyDomain)) else { return nil }
        save(host: host, username: username, password: secret, modified: login.modified)
        return secret
    }

    private func read(_ query: [String: Any]) -> String? {
        var query = query
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    public func save(host: String, username: String, password: String, modified: Date) {
        let data = Data(password.utf8)
        let attrs: [String: Any] = [kSecValueData as String: data, kSecAttrGeneric as String: Self.encode(modified)]
        let update = SecItemUpdate(base(host: host, username: username) as CFDictionary, attrs as CFDictionary)
        if update == errSecItemNotFound {
            var add = base(host: host, username: username)
            add.merge(attrs) { $1 }
            add[kSecAttrLabel as String] = "Vega: \(PasswordHosts.normalized(host))"
            add[kSecAttrProtocol as String] = kSecAttrProtocolHTTPS
            SecItemAdd(add as CFDictionary, nil)
        }
        forgetTombstone(host: host, username: username)
    }

    public func delete(host: String, username: String, at: Date) {
        SecItemDelete(base(host: host, username: username) as CFDictionary)
        // An old copy cannot be deleted without a dialog: hide it instead.
        if readsLegacy, !items(in: Self.legacyDomain).filter({ $0.host == PasswordHosts.normalized(host) && $0.username == username }).isEmpty {
            let id = SavedLogin(host: PasswordHosts.normalized(host), username: username).id
            var hidden = UserDefaults.standard.stringArray(forKey: Self.hiddenKey) ?? []
            if !hidden.contains(id) { hidden.append(id); UserDefaults.standard.set(hidden, forKey: Self.hiddenKey) }
        }
        var all = storedTombstones().filter { $0.key != PasswordRecord(host: PasswordHosts.normalized(host), username: username, password: "", modified: at).key }
        all.append(PasswordRecord(host: PasswordHosts.normalized(host), username: username, password: "", modified: at, deleted: true))
        storeTombstones(all)
    }

    /// Removes every saved login of this vault and the remembered deletions. Old items from before `.v2` cannot be
    /// deleted without a dialog, so they are hidden instead.
    public func deleteAll() {
        let old = readsLegacy ? items(in: Self.legacyDomain).map(\.id) : []
        SecItemDelete(base(domain: domain) as CFDictionary)
        if !old.isEmpty {
            var hidden = Set(UserDefaults.standard.stringArray(forKey: Self.hiddenKey) ?? [])
            hidden.formUnion(old)
            UserDefaults.standard.set(Array(hidden), forKey: Self.hiddenKey)
        }
        UserDefaults.standard.removeObject(forKey: tombstoneKey)
    }

    // MARK: - Remembered deletions (no secrets in them)

    /// Each vault remembers its own deletions; the first profile keeps the original key.
    private var tombstoneKey: String { readsLegacy ? "fork.passwords.tombstones" : "fork.passwords.tombstones.\(domain)" }

    public func tombstones() -> [PasswordRecord] { PasswordMerge.pruned(storedTombstones()) }

    private func storedTombstones() -> [PasswordRecord] {
        guard let data = UserDefaults.standard.data(forKey: tombstoneKey) else { return [] }
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .millisecondsSince1970
        return (try? decoder.decode([PasswordRecord].self, from: data)) ?? []
    }

    private func storeTombstones(_ records: [PasswordRecord]) {
        let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .millisecondsSince1970
        UserDefaults.standard.set(try? encoder.encode(PasswordMerge.pruned(records)), forKey: tombstoneKey)
    }

    private func forgetTombstone(host: String, username: String) {
        let key = PasswordRecord(host: PasswordHosts.normalized(host), username: username, password: "", modified: Date()).key
        let all = storedTombstones()
        if all.contains(where: { $0.key == key }) { storeTombstones(all.filter { $0.key != key }) }
    }
}
