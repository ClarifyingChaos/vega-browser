// Licensed under GPL-3.0. See LICENSE.
//
//  SealedSync.swift
//  VegaWeb
//
//  FORK: spaces, favorites and settings sealed with the sync passphrase, as passwords and open tabs already are, so
//  iCloud Drive or Google Drive holds nothing it can read. A Mac writes "devices/<id>.enc" and "settings/<id>.enc"
//  when it has the key. While a Mac that only reads plain files (an older Vega, or one without the passphrase) has
//  written in the last 30 days, the plain copy is written too; after that the plain copy is replaced with an empty one.
//

import CryptoKit
import Foundation
#if canImport(VegaTabsCore)
import VegaTabsCore
#endif

public enum SealedSync {
    static let recentDays: Double = 30

    /// Other Macs' snapshots: the sealed copy when there is one this key opens, else the plain one. `plainOnly` lists
    /// the Macs that wrote recently but never a sealed copy: while there are any, this Mac keeps a plain copy for them.
    public static func readOthers(_ store: any SyncBlobStore, excluding own: UUID, key: SymmetricKey?,
                                  now: Date = Date()) async throws -> (snapshots: [SyncSnapshot], pending: Int, plainOnly: Set<UUID>) {
        let (names, pending) = try await store.list("devices")
        var plain: [UUID: SyncSnapshot] = [:], sealed: [UUID: SyncSnapshot] = [:], hasSealedFile = Set<UUID>()
        for name in names {
            let isSealed = name.hasSuffix(".enc")
            guard isSealed || name.hasSuffix(".json"), let id = UUID(uuidString: String(name.dropLast(isSealed ? 4 : 5))), id != own else { continue }
            if isSealed { hasSealedFile.insert(id) }
            if isSealed && key == nil { continue }
            guard let data = try await store.get("devices/\(name)") else { continue }
            if isSealed {
                if let key, let opened = PasswordCrypto.open(data, with: key), let s = SyncSnapshot.decoded(opened), s.deviceID == id { sealed[id] = s }
            } else if let s = SyncSnapshot.decoded(data), s.deviceID == id {
                plain[id] = s
            }
        }
        var out: [SyncSnapshot] = []
        for id in Set(plain.keys).union(sealed.keys) {
            // A Mac that switched writes both for a while: the newer one counts.
            let candidates = [sealed[id], plain[id]].compactMap { $0 }
            if let best = candidates.max(by: { $0.writtenAt < $1.writtenAt }) { out.append(best) }
        }
        let cutoff = now.addingTimeInterval(-recentDays * 86_400)
        let plainOnly = Set(plain.filter { !hasSealedFile.contains($0.key) && $0.value.writtenAt > cutoff && !$0.value.spaces.isEmpty }.keys)
        return (out, pending, plainOnly)
    }

    /// This Mac's snapshot: sealed when there is a key, plain while some Mac still reads only plain files.
    public static func write(_ snapshot: SyncSnapshot, to store: any SyncBlobStore, key: SymmetricKey?, plainNeeded: Bool) async throws {
        guard let key else {
            try await store.writeSnapshot(snapshot)
            return
        }
        try await store.put("devices/\(snapshot.deviceID.uuidString).enc", PasswordCrypto.seal(snapshot.encoded(), with: key))
        if plainNeeded {
            try await store.writeSnapshot(snapshot)
        } else {
            // What the plain file held is replaced: an empty snapshot changes nothing on a Mac that reads it.
            try await store.writeSnapshot(SyncSnapshot(deviceID: snapshot.deviceID, deviceName: snapshot.deviceName,
                                                       writtenAt: snapshot.writtenAt, spaces: [], items: []))
        }
    }
}
