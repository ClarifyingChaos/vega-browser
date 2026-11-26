// Licensed under GPL-3.0. See LICENSE.
//
//  SealedSyncCheck.swift
//  Nook
//
//  Sync believes only files sealed with the sync passphrase: snapshots hold no names in plain text, a readable or
//  wrongly keyed file is ignored, and only a sealed marker that names a Mac removes it. Compiles the shipped sources:
//
//    swiftc Packages/NookTabsCore/Sources/NookTabsCore/*.swift \
//           Packages/NookWeb/Sources/NookWeb/Passwords/PasswordSync.swift \
//           Packages/NookWeb/Sources/NookWeb/SealedSync.swift \
//           Packages/NookWeb/Checks/SealedSyncCheck.swift -o /tmp/sealed-sync-check && /tmp/sealed-sync-check
//

import CryptoKit
import Foundation

@main
struct SealedSyncCheck {
    static func main() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("sealed-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = FolderBlobStore(url: dir)
        let key = SymmetricKey(size: .bits256)
        let macA = UUID(), macB = UUID(), planted = UUID()

        var tree = TabTree()
        tree.createSpace(id: UUID(), name: "Secret Space", icon: "", accentHex: "#000000", after: nil, now: Date())
        let snapshotA = SyncMerge.snapshot(of: tree, deviceID: macA, deviceName: "A")

        try await SealedSync.write(snapshotA, to: store, key: key)
        let seen = try await SealedSync.readOthers(store, excluding: macB, key: key)
        precondition(seen.snapshots.map(\.deviceID) == [macA] && seen.snapshots[0].spaces.first?.name == "Secret Space", "B reads A")
        for name in ["\(macA.uuidString).enc", "\(macA.uuidString).json"] {
            let bytes = try Data(contentsOf: dir.appendingPathComponent("devices/\(name)"))
            precondition(!String(decoding: bytes, as: UTF8.self).contains("Secret Space"), "no space names in plain text: \(name)")
        }

        // Readable files written by someone with the sync place, and a file sealed with another key, are ignored.
        let fake = SyncSnapshot(deviceID: planted, deviceName: "Planted", spaces: snapshotA.spaces, items: [])
        try await store.put("devices/\(planted.uuidString).json", fake.encoded())
        try await store.put("devices/\(planted.uuidString).enc", fake.encoded())
        let after = try await SealedSync.readOthers(store, excluding: macB, key: key)
        precondition(after.snapshots.map(\.deviceID) == [macA], "nothing unsealed is believed")
        let wrong = try await SealedSync.readOthers(store, excluding: macB, key: SymmetricKey(size: .bits256))
        precondition(wrong.snapshots.isEmpty)

        // Removal: only a marker sealed with this key, under the name it was sealed for.
        let found1 = await SealedSync.removedDevices(store, key: key)
        precondition(found1.isEmpty)
        try await store.put("removed/\(macA.uuidString).json", Data(#"{"removed":true}"#.utf8))
        try await store.put("removed/\(macA.uuidString).enc", Data(#"{"removed":true}"#.utf8))
        let found2 = await SealedSync.removedDevices(store, key: key)
        precondition(found2.isEmpty, "a planted marker removes nobody")
        try await SealedSync.setRemoved(macA, true, in: store, key: SymmetricKey(size: .bits256))
        let found3 = await SealedSync.removedDevices(store, key: key)
        precondition(found3.isEmpty)
        try await SealedSync.setRemoved(macA, true, in: store, key: key)
        let found4 = await SealedSync.removedDevices(store, key: key)
        precondition(found4 == [macA])
        let marker = try await store.get("removed/\(macA.uuidString).enc")!
        try await store.put("removed/\(macB.uuidString).enc", marker)
        let found5 = await SealedSync.removedDevices(store, key: key)
        precondition(found5 == [macA], "a copied marker removes nobody else")
        try await SealedSync.setRemoved(macA, false, in: store, key: key)
        let found6 = await SealedSync.removedDevices(store, key: key)
        precondition(found6.isEmpty, "a Mac can join again")
        // A Mac an older Vega removed stays left out, until a sealed marker says otherwise.
        let former = UUID()
        try await store.put("removed/\(former.uuidString).json", Data(#"{"removed":true}"#.utf8))
        let left = await SealedSync.formerlyRemoved(store)
        precondition(left.contains(former) && !left.contains(macA), "\(left)")
        try await SealedSync.setRemoved(former, false, in: store, key: key)
        let back = await SealedSync.formerlyRemoved(store)
        precondition(!back.contains(former))
        print("SealedSyncCheck passed")
    }
}
