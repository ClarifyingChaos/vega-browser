// Licensed under GPL-3.0. See LICENSE.
//
//  SealedSyncCheck.swift
//  Nook
//
//  Spaces sealed with the sync passphrase: the files hold no names in plain text once every Mac reads sealed
//  copies, a Mac that only reads plain files keeps getting them, the sealed copy wins when newer, and a wrong key
//  reads only the plain copies. Compiles the shipped sources:
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
        let macA = UUID(), macB = UUID(), oldMac = UUID()

        var tree = TabTree()
        let space = UUID()
        tree.createSpace(id: space, name: "Secret Space", icon: "", accentHex: "#000000", after: nil, now: Date())
        let snapshotA = SyncMerge.snapshot(of: tree, deviceID: macA, deviceName: "A")

        func plainFile(_ id: UUID) -> String { (try? String(contentsOf: dir.appendingPathComponent("devices/\(id.uuidString).json"), encoding: .utf8)) ?? "" }

        // An older Mac that writes only plain files: A keeps a plain copy for it.
        try await store.writeSnapshot(SyncSnapshot(deviceID: oldMac, deviceName: "Old", spaces: snapshotA.spaces, items: []))
        let seenByA = try await SealedSync.readOthers(store, excluding: macA, key: key)
        precondition(seenByA.plainOnly == [oldMac], "the older Mac is noticed")
        try await SealedSync.write(snapshotA, to: store, key: key, plainNeeded: !seenByA.plainOnly.isEmpty)
        precondition(plainFile(macA).contains("Secret Space"), "plain copy kept while a Mac needs it")
        precondition(FileManager.default.fileExists(atPath: dir.appendingPathComponent("devices/\(macA.uuidString).enc").path))

        // B (with the key) reads A's sealed copy; a wrong key still reads A's plain copy.
        let seenByB = try await SealedSync.readOthers(store, excluding: macB, key: key)
        precondition(seenByB.snapshots.contains { $0.deviceID == macA && $0.spaces.first?.name == "Secret Space" }, "B reads A")
        let wrong = try await SealedSync.readOthers(store, excluding: macB, key: SymmetricKey(size: .bits256))
        precondition(wrong.snapshots.contains { $0.deviceID == macA }, "a wrong key falls back to the plain copy")

        // The older Mac updates and writes sealed too: A drops its plain copy for an empty one.
        try await SealedSync.write(SyncSnapshot(deviceID: oldMac, deviceName: "Old", spaces: snapshotA.spaces, items: []), to: store, key: key, plainNeeded: false)
        let again = try await SealedSync.readOthers(store, excluding: macA, key: key)
        precondition(again.plainOnly.isEmpty, "no Mac needs plain files any more")
        try await SealedSync.write(snapshotA, to: store, key: key, plainNeeded: !again.plainOnly.isEmpty)
        precondition(!plainFile(macA).contains("Secret Space"), "no space names in plain text")
        let sealedBytes = try Data(contentsOf: dir.appendingPathComponent("devices/\(macA.uuidString).enc"))
        precondition(!String(decoding: sealedBytes, as: UTF8.self).contains("Secret Space"), "the sealed copy is unreadable")

        // A Mac reading both copies of A takes the newer: the sealed one with the space.
        let both = try await SealedSync.readOthers(store, excluding: macB, key: key)
        precondition(both.snapshots.first { $0.deviceID == macA }?.spaces.isEmpty == false, "sealed (newer or equal) copy wins over the empty plain one")

        // The empty plain copy changes nothing for a Mac that reads it.
        let empty = try await SealedSync.readOthers(store, excluding: macB, key: nil)
        guard let stub = empty.snapshots.first(where: { $0.deviceID == macA }) else { fatalError("plain stub missing") }
        precondition(SyncMerge.change(applying: stub, to: tree).isEmpty, "an empty snapshot changes nothing")
        print("SealedSyncCheck passed")
    }
}

