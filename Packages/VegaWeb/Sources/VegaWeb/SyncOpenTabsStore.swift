// Licensed under GPL-3.0. See LICENSE.
//
//  SyncOpenTabsStore.swift
//  VegaWeb
//
//  FORK: the tabs open on each Mac, listed on the others. Read only: a tab opened from the list is a new tab
//  here, and nothing is merged into this Mac's own tabs. Each Mac writes one small file to the same folder
//  as the rest of sync, only when "Share open tabs" is on.
//

import CryptoKit
import Foundation
#if canImport(VegaTabsCore)
import VegaTabsCore
#endif

public extension OpenTabsSnapshot {
    /// The address without its query, fragment or login: those carry tokens and search terms, and the files are
    /// plain text in iCloud or Drive.
    static func clean(_ url: URL) -> URL? {
        var parts = URLComponents(url: url, resolvingAgainstBaseURL: false)
        parts?.query = nil; parts?.fragment = nil; parts?.user = nil; parts?.password = nil
        return parts?.url
    }
}

public struct OpenTabsSnapshot: Codable, Equatable, Sendable, Identifiable {
    public struct Entry: Codable, Equatable, Sendable, Identifiable {
        public var title: String
        public var url: String
        public var space: String
        public var id: String { url + "\u{0}" + space }
    }
    public var deviceID: UUID
    public var deviceName: String
    public var writtenAt: Date
    public var tabs: [Entry]
    public var id: UUID { deviceID }
}

extension SyncBlobStore {
    private static var tabsEncoder: JSONEncoder { let e = JSONEncoder(); e.dateEncodingStrategy = .millisecondsSince1970; e.outputFormatting = [.sortedKeys]; return e }
    private static var tabsDecoder: JSONDecoder { let d = JSONDecoder(); d.dateDecodingStrategy = .millisecondsSince1970; return d }

    /// With a key, the list is sealed (AES-GCM) in an `.enc` file and keeps its full addresses; the plain `.json`
    /// is emptied. Without one, it is plain text and the addresses must already be cleaned.
    func writeOpenTabs(_ snapshot: OpenTabsSnapshot, key: SymmetricKey? = nil) async throws {
        let id = snapshot.deviceID.uuidString
        let json = try Self.tabsEncoder.encode(snapshot)
        if let key {
            try await put("openTabs/\(id).enc", PasswordCrypto.seal(json, with: key))
            var empty = snapshot; empty.tabs = []
            try await put("openTabs/\(id).json", Self.tabsEncoder.encode(empty))
        } else {
            try await put("openTabs/\(id).json", json)
        }
    }

    /// Other Macs' lists. A Mac that stopped sharing leaves an empty list; one not heard from in two weeks is left out.
    func readOtherOpenTabs(excluding own: UUID, key: SymmetricKey? = nil) async throws -> [OpenTabsSnapshot] {
        let (names, _) = try await list("openTabs")
        var byDevice: [UUID: OpenTabsSnapshot] = [:]
        let cutoff = Date().addingTimeInterval(-14 * 86_400)
        for name in names where (name.hasSuffix(".json") || name.hasSuffix(".enc")) && !name.hasPrefix(own.uuidString) {
            guard var data = try await get("openTabs/\(name)") else { continue }
            if name.hasSuffix(".enc") {
                // A sealed list opens only with this Mac's key; without it the list is simply not shown.
                guard let key, let opened = PasswordCrypto.open(data, with: key) else { continue }
                data = opened
            }
            guard let snapshot = try? Self.tabsDecoder.decode(OpenTabsSnapshot.self, from: data),
                  snapshot.deviceID != own, snapshot.writtenAt > cutoff, !snapshot.tabs.isEmpty else { continue }
            // A Mac that has both files (it just switched) shows its newest.
            if let existing = byDevice[snapshot.deviceID], existing.writtenAt >= snapshot.writtenAt { continue }
            byDevice[snapshot.deviceID] = snapshot
        }
        return byDevice.values.sorted { $0.writtenAt > $1.writtenAt }
    }
}

