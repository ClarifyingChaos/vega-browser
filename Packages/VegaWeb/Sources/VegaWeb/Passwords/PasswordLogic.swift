// Licensed under GPL-3.0. See LICENSE.
//
//  PasswordLogic.swift
//  VegaWeb
//
//  FORK: the parts of Vega's password manager that need no Keychain or web view: which saved
//  logins a page may use, the in-memory vault the tests run on, and Chrome/Safari CSV import.
//

import Foundation

/// A saved login, without its password: the list never carries secrets.
public struct SavedLogin: Identifiable, Hashable, Sendable {
    public let host: String
    public let username: String
    public var modified: Date
    public var id: String { host + "\u{1F}" + username }

    public init(host: String, username: String, modified: Date = Date()) {
        self.host = host
        self.username = username
        self.modified = modified
    }
}

public protocol PasswordVault: AnyObject {
    func all() -> [SavedLogin]
    func password(host: String, username: String) -> String?
    func save(host: String, username: String, password: String, modified: Date)
    func delete(host: String, username: String, at: Date)
    /// Deletions the vault remembers, so sync can pass them on.
    func tombstones() -> [PasswordRecord]
    /// Runs `body` so that nothing is ever asked of the person: an item the system would ask about is skipped.
    /// Sync works in the background and must never put a dialog in front of someone browsing.
    func quietly<T>(_ body: () -> T) -> T
    /// Logins sync can't read without asking (an older Vega's Keychain items).
    func legacyCount() -> Int
    /// Those logins themselves (host and username only).
    func legacyOnly() -> [SavedLogin]
    /// The login's verification-code generator, if one was set up.
    func totp(host: String, username: String) -> TOTP?
    /// Whether one is set up, without reading the secret.
    func hasTOTP(host: String, username: String) -> Bool
    func setTOTP(_ totp: TOTP?, host: String, username: String)
    /// The logins this vault hands over without asking: exactly what sync sends.
    func readable() -> [SavedLogin]
    /// Every readable login with its password, plus the remembered deletions.
    func records() -> [PasswordRecord]
}

public extension PasswordVault {
    func quietly<T>(_ body: () -> T) -> T { body() }
    func legacyCount() -> Int { 0 }
    func legacyOnly() -> [SavedLogin] { [] }
    func totp(host: String, username: String) -> TOTP? { nil }
    func hasTOTP(host: String, username: String) -> Bool { false }
    func setTOTP(_ totp: TOTP?, host: String, username: String) {}
    func readable() -> [SavedLogin] { all() }
    func save(host: String, username: String, password: String) { save(host: host, username: username, password: password, modified: Date()) }
    func delete(host: String, username: String) { delete(host: host, username: username, at: Date()) }

    func records() -> [PasswordRecord] {
        all().compactMap { login in
            password(host: login.host, username: login.username).map {
                PasswordRecord(host: login.host, username: login.username, password: $0, modified: login.modified)
            }
        } + tombstones()
    }

    /// Writes records from another Mac, with their own timestamps.
    func apply(_ records: [PasswordRecord]) {
        for r in records {
            if r.deleted { delete(host: r.host, username: r.username, at: r.modified) }
            else { save(host: r.host, username: r.username, password: r.password, modified: r.modified) }
        }
    }
}

public enum PasswordHosts {
    /// Lower case, no "www.", no port, no trailing dot.
    public static func normalized(_ host: String) -> String {
        var h = host.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: ". "))
        if h.hasPrefix("www.") { h.removeFirst(4) }
        return h
    }

    /// example.com for login.example.com, by the Public Suffix List: alice.github.io is its own site, not github.io's.
    /// An IP address or single label is its own.
    public static func registrable(_ host: String) -> String {
        PublicSuffixList.shared.registrable(normalized(host))
    }

    /// A page may use a login saved for its own site or a sibling subdomain, never another site.
    public static func matches(saved: String, page: String) -> Bool {
        let s = normalized(saved), p = normalized(page)
        return s == p || registrable(s) == registrable(p)
    }

    /// Plain http is trusted for the machine itself only.
    public static func isUsable(scheme: String?, host: String?) -> Bool {
        guard let host else { return false }
        if scheme == "https" { return true }
        return scheme == "http" && (host == "localhost" || host == "127.0.0.1" || host.hasSuffix(".localhost"))
    }
}

public extension PasswordVault {
    func logins(forPageHost page: String) -> [SavedLogin] {
        all().filter { PasswordHosts.matches(saved: $0.host, page: page) }
            .sorted { ($0.host == PasswordHosts.normalized(page) ? 0 : 1, $0.username.lowercased()) < ($1.host == PasswordHosts.normalized(page) ? 0 : 1, $1.username.lowercased()) }
    }
}

/// For tests.
public final class MemoryVault: PasswordVault {
    private var items: [String: (login: SavedLogin, password: String)] = [:]
    private var gone: [String: PasswordRecord] = [:]
    public init() {}
    public func all() -> [SavedLogin] { items.values.map(\.login) }
    public func password(host: String, username: String) -> String? { items[SavedLogin(host: PasswordHosts.normalized(host), username: username).id]?.password }
    public func save(host: String, username: String, password: String, modified: Date) {
        let login = SavedLogin(host: PasswordHosts.normalized(host), username: username, modified: modified)
        items[login.id] = (login, password)
        gone[login.id] = nil
    }
    public func delete(host: String, username: String, at: Date) {
        let h = PasswordHosts.normalized(host)
        let id = SavedLogin(host: h, username: username).id
        items[id] = nil
        gone[id] = PasswordRecord(host: h, username: username, password: "", modified: at, deleted: true)
    }
    public func tombstones() -> [PasswordRecord] { Array(gone.values) }
}

public enum PasswordCSV {
    public struct Row: Equatable, Sendable { public var host: String; public var username: String; public var password: String }

    /// Rows of a Chrome or Safari export. Columns are found by name (url, username, password); rows
    /// without all three are skipped, and a url without a scheme is read as https.
    public static func parse(_ text: String) -> (rows: [Row], skipped: Int) {
        let records = records(text)
        guard let header = records.first?.map({ $0.lowercased().trimmingCharacters(in: .whitespaces) }),
              let u = header.firstIndex(where: { $0 == "url" || $0 == "origin" || $0 == "website" }),
              let n = header.firstIndex(where: { $0 == "username" || $0 == "login" || $0 == "user" }),
              let p = header.firstIndex(of: "password") else { return ([], max(records.count - 1, 0)) }
        var rows: [Row] = [], skipped = 0
        for record in records.dropFirst() {
            guard record.count > max(u, n, p) else { skipped += 1; continue }
            let raw = record[u].trimmingCharacters(in: .whitespaces)
            let host = (URL(string: raw)?.host ?? URL(string: "https://" + raw)?.host).map(PasswordHosts.normalized)
            guard let host, !host.isEmpty, !record[n].isEmpty, !record[p].isEmpty else { skipped += 1; continue }
            rows.append(Row(host: host, username: record[n], password: record[p]))
        }
        return (rows, skipped)
    }

    /// RFC 4180: quoted fields may hold commas, quotes ("") and line breaks.
    static func records(_ text: String) -> [[String]] {
        var out: [[String]] = [], row: [String] = [], field = "", quoted = false
        var chars = Array(text.replacingOccurrences(of: "\r\n", with: "\n")).makeIterator()
        var next = chars.next()
        while let c = next {
            next = chars.next()
            if quoted {
                if c == "\"" { if next == "\"" { field.append("\""); next = chars.next() } else { quoted = false } } else { field.append(c) }
            } else if c == "\"" { quoted = true }
            else if c == "," { row.append(field); field = "" }
            else if c == "\n" { row.append(field); field = ""; if !(row.count == 1 && row[0].isEmpty) { out.append(row) }; row = [] }
            else { field.append(c) }
        }
        if !field.isEmpty || !row.isEmpty { row.append(field); out.append(row) }
        return out
    }
}
