// Licensed under GPL-3.0. See LICENSE.
//
//  SealedSync.swift
//  NookWeb
//
//  FORK: spaces, favorites and removals sealed with the sync passphrase, as passwords and open tabs already are, so
//  iCloud Drive, Google Drive or the sync server holds nothing it can read, and nothing it writes itself is believed.
//  Only files this key opens are read. A Mac writes "devices/<id>.enc", and an empty "devices/<id>.json" over the
//  readable copy an older Vega wrote.
//

import CryptoKit
import Foundation
#if canImport(NookTabsCore)
import NookTabsCore
#endif

public enum SealedSync {
    /// Other Macs' snapshots that this key opens. A readable file is ignored: anyone who can write to the sync
    /// place could have put it there.
    public static func readOthers(_ store: any SyncBlobStore, excluding own: UUID,
                                  key: SymmetricKey) async throws -> (snapshots: [SyncSnapshot], pending: Int) {
        let (names, pending) = try await store.list("devices")
        var out: [SyncSnapshot] = []
        for name in names where name.hasSuffix(".enc") {
            guard let id = UUID(uuidString: String(name.dropLast(4))), id != own,
                  let data = try await store.get("devices/\(name)"), let opened = PasswordCrypto.open(data, with: key),
                  let snapshot = SyncSnapshot.decoded(opened), snapshot.deviceID == id else { continue }
            out.append(snapshot)
        }
        return (out, pending)
    }

    /// This Mac's snapshot, sealed.
    public static func write(_ snapshot: SyncSnapshot, to store: any SyncBlobStore, key: SymmetricKey) async throws {
        try await store.put("devices/\(snapshot.deviceID.uuidString).enc", PasswordCrypto.seal(snapshot.encoded(), with: key))
        // What a readable file held is replaced: an empty snapshot changes nothing on a Mac that reads it.
        try await store.put("devices/\(snapshot.deviceID.uuidString).json",
                            SyncSnapshot(deviceID: snapshot.deviceID, deviceName: snapshot.deviceName,
                                         writtenAt: snapshot.writtenAt, spaces: [], items: []).encoded())
    }

    // MARK: - Removed Macs

    /// The Mac is named inside the seal, so one Mac's marker copied under another's name removes nobody.
    private struct Removal: Codable { var id: UUID; var removed: Bool }

    /// A Mac taken out of the chain from another Mac, as "removed/<id>.enc": the others stop reading it, and it
    /// turns its own sync off and erases what sync brought. Only a marker sealed with this key counts.
    public static func removedDevices(_ store: any SyncBlobStore, key: SymmetricKey) async -> Set<UUID> {
        guard let names = try? await store.list("removed").names else { return [] }
        var out: Set<UUID> = []
        for name in names where name.hasSuffix(".enc") {
            guard let id = UUID(uuidString: String(name.dropLast(4))),
                  let data = try? await store.get("removed/\(name)"), let opened = PasswordCrypto.open(data, with: key),
                  let marker = try? JSONDecoder().decode(Removal.self, from: opened), marker.id == id, marker.removed else { continue }
            out.insert(id)
        }
        return out
    }

    /// Macs an older Vega removed, with a readable marker and no sealed one since. They are only left out, never
    /// erased on that word: leaving a Mac out is no more than anyone with the sync place could do by deleting its files.
    public static func formerlyRemoved(_ store: any SyncBlobStore) async -> Set<UUID> {
        guard let names = try? await store.list("removed").names else { return [] }
        var out: Set<UUID> = []
        for name in names where name.hasSuffix(".json") && !names.contains(name.dropLast(5) + ".enc") {
            guard let id = UUID(uuidString: String(name.dropLast(5))), let data = try? await store.get("removed/\(name)"),
                  (try? JSONDecoder().decode([String: Bool].self, from: data))?["removed"] == true else { continue }
            out.insert(id)
        }
        return out
    }

    /// Writing `removed: false` over a marker lets the Mac join again.
    public static func setRemoved(_ id: UUID, _ removed: Bool, in store: any SyncBlobStore, key: SymmetricKey) async throws {
        try await store.put("removed/\(id.uuidString).enc",
                            PasswordCrypto.seal(JSONEncoder().encode(Removal(id: id, removed: removed)), with: key))
    }
}
