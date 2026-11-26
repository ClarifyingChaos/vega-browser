// Licensed under GPL-3.0. See LICENSE.
//
//  SyncOpenTabsStore.swift
//  NookWeb
//
//  FORK: the tabs open on each Mac, listed on the others. Read only: a tab opened from the list is a new tab
//  here, and nothing is merged into this Mac's own tabs. Each Mac writes one small file to the same folder
//  as the rest of sync, only when "Share open tabs" is on.
//

import CryptoKit
import Foundation
#if canImport(NookTabsCore)
import NookTabsCore
#endif

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

    /// The list sealed (AES-GCM) in an `.enc` file; the readable `.json` an older Vega wrote is emptied.
    func writeOpenTabs(_ snapshot: OpenTabsSnapshot, key: SymmetricKey) async throws {
        let id = snapshot.deviceID.uuidString
        try await put("openTabs/\(id).enc", PasswordCrypto.seal(Self.tabsEncoder.encode(snapshot), with: key))
        var empty = snapshot; empty.tabs = []
        try await put("openTabs/\(id).json", Self.tabsEncoder.encode(empty))
    }

    /// Other Macs' lists that this key opens. A Mac that stopped sharing leaves an empty list; one not heard from
    /// in two weeks is left out.
    func readOtherOpenTabs(excluding own: UUID, key: SymmetricKey) async throws -> [OpenTabsSnapshot] {
        let (names, _) = try await list("openTabs")
        var out: [OpenTabsSnapshot] = []
        let cutoff = Date().addingTimeInterval(-14 * 86_400)
        for name in names where name.hasSuffix(".enc") && !name.hasPrefix(own.uuidString) {
            guard let data = try await get("openTabs/\(name)"), let opened = PasswordCrypto.open(data, with: key),
                  let snapshot = try? Self.tabsDecoder.decode(OpenTabsSnapshot.self, from: opened),
                  name == "\(snapshot.deviceID.uuidString).enc", snapshot.deviceID != own,
                  snapshot.writtenAt > cutoff, !snapshot.tabs.isEmpty else { continue }
            out.append(snapshot)
        }
        return out.sorted { $0.writtenAt > $1.writtenAt }
    }
}
