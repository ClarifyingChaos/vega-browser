// Licensed under GPL-3.0. See LICENSE.
//
//  PasswordSyncCheck.swift
//  Vega
//
//  Two Macs sharing a folder: a login saved on one reaches the other, a deletion follows, the
//  files hold no plaintext, and a wrong passphrase reads nothing. Compiles the shipped sources:
//
//    swiftc Packages/VegaTabsCore/Sources/VegaTabsCore/*.swift \
//           Packages/VegaWeb/Sources/VegaWeb/Passwords/PasswordLogic.swift \
//           Packages/VegaWeb/Sources/VegaWeb/Passwords/PasswordSync.swift \
//           Packages/VegaWeb/Sources/VegaWeb/Passwords/PasswordSyncStore.swift \
//           Packages/VegaWeb/Checks/PasswordSyncCheck.swift -o /tmp/password-sync-check && /tmp/password-sync-check
//

import CryptoKit
import Foundation

@main
struct PasswordSyncCheck {
    static func main() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("pwsync-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = PasswordSyncStore(store: FolderBlobStore(url: dir))
        let macA = UUID(), macB = UUID()
        let vaultA = MemoryVault(), vaultB = MemoryVault()

        // Mac A sets the passphrase up; Mac B joins with the same one.
        let made = try PasswordSyncMeta.create(passphrase: "a long passphrase", iterations: 1_000)
        try await store.writeMeta(made.meta)
        let metaB = try await store.meta()
        let keyB = metaB?.key(for: "a long passphrase")
        precondition(keyB != nil, "same passphrase opens on the other Mac")
        precondition(metaB?.key(for: "another passphrase") == nil, "a wrong passphrase is refused")

        func tick(_ vault: MemoryVault, _ me: UUID, _ key: SymmetricKey) async throws {
            let (others, _) = try await store.readOthers(excluding: me, key: key)
            for snapshot in others {
                let light = vault.all().map { PasswordRecord(host: $0.host, username: $0.username, password: "", modified: $0.modified) } + vault.tombstones()
                vault.apply(PasswordMerge.changes(applying: snapshot.records, to: light))
            }
            try await store.write(PasswordSnapshot(deviceID: me, records: vault.records()), key: key)
        }

        vaultA.save(host: "example.com", username: "amy", password: "s3cret")
        try await tick(vaultA, macA, made.key)
        try await tick(vaultB, macB, keyB!)
        precondition(vaultB.password(host: "example.com", username: "amy") == "s3cret", "login reaches the other Mac")

        // The files hold nothing readable.
        for name in try FileManager.default.contentsOfDirectory(atPath: dir.appendingPathComponent("passwords").path) where name.hasSuffix(".enc") {
            let raw = try Data(contentsOf: dir.appendingPathComponent("passwords/\(name)"))
            precondition(!String(decoding: raw, as: UTF8.self).contains("s3cret") && !String(decoding: raw, as: UTF8.self).contains("example.com"))
        }
        let wrong = PasswordCrypto.deriveKey(passphrase: "nope nope nope", salt: made.meta.salt, iterations: 1_000)
        let leaked = try await store.readOthers(excluding: UUID(), key: wrong)
        precondition(leaked.snapshots.isEmpty, "the wrong key reads nothing")

        // A login another Mac only re-stamps (newer time, same password) is not news; a different password or a
        // deletion is; one this Mac cannot read right now is left alone.
        let stamp = Date().addingTimeInterval(60)
        func rec(_ host: String, _ pw: String, deleted: Bool = false) -> PasswordRecord { PasswordRecord(host: host, username: "u", password: pw, modified: stamp, deleted: deleted) }
        let mine: [String: String?] = ["same.com": "pw", "changed.com": "old", "locked.com": nil]
        let readable = Set(["same.com", "changed.com", "locked.com"].map { rec($0, "").key })
        let worth = PasswordMerge.worthApplying([rec("same.com", "pw"), rec("changed.com", "new"), rec("locked.com", "x"), rec("gone.com", "", deleted: true), rec("fresh.com", "p")],
                                                readable: readable) { mine[$0.host] ?? nil }
        precondition(worth.map(\.host) == ["changed.com", "gone.com", "fresh.com"], "only real changes are applied: \(worth.map(\.host))")

        // A change on B (newer) and then a deletion travel back to A.
        try await Task.sleep(for: .milliseconds(20))
        vaultB.save(host: "example.com", username: "amy", password: "changed")
        try await tick(vaultB, macB, keyB!)
        try await tick(vaultA, macA, made.key)
        precondition(vaultA.password(host: "example.com", username: "amy") == "changed", "newer password wins")
        try await Task.sleep(for: .milliseconds(20))
        vaultB.delete(host: "example.com", username: "amy")
        try await tick(vaultB, macB, keyB!)
        try await tick(vaultA, macA, made.key)
        precondition(vaultA.password(host: "example.com", username: "amy") == nil, "deletion travels")
        try await tick(vaultB, macB, keyB!)
        precondition(vaultB.password(host: "example.com", username: "amy") == nil, "and does not come back")
        print("PasswordSyncCheck passed")
    }
}
