// Licensed under GPL-3.0. See LICENSE.
//
//  OpenTabsSyncCheck.swift
//  Nook
//
//  Two Macs sharing a folder: each sees the other's open tabs and never its own, a Mac that stopped
//  sharing (an empty list) and one not heard from in two weeks drop out. Compiles the shipped sources:
//
//    swiftc Packages/NookTabsCore/Sources/NookTabsCore/*.swift \
//           Packages/NookWeb/Sources/NookWeb/SyncOpenTabsStore.swift Packages/NookWeb/Sources/NookWeb/Passwords/PasswordSync.swift \
//           Packages/NookWeb/Checks/OpenTabsSyncCheck.swift -o /tmp/open-tabs-sync-check && /tmp/open-tabs-sync-check
//

import CryptoKit
import Foundation

@main
struct OpenTabsSyncCheck {
    static func main() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("opentabs-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = FolderBlobStore(url: dir)
        let a = UUID(), b = UUID(), stopped = UUID(), stale = UUID()
        func snap(_ id: UUID, _ name: String, _ tabs: [OpenTabsSnapshot.Entry], at date: Date = Date()) -> OpenTabsSnapshot {
            OpenTabsSnapshot(deviceID: id, deviceName: name, writtenAt: date, tabs: tabs)
        }
        precondition(OpenTabsSnapshot.clean(URL(string: "https://u:p@bank.example/acct?token=SECRET&q=x#frag")!)?.absoluteString == "https://bank.example/acct", "query, fragment and login are dropped")
        let tab = { (t: String, u: String) in OpenTabsSnapshot.Entry(title: t, url: u, space: "Personal") }
        try await store.writeOpenTabs(snap(a, "Studio", [tab("Apple", "https://apple.com"), tab("Swift", "https://swift.org")]))
        try await store.writeOpenTabs(snap(b, "Laptop", [tab("Vega", "https://example.com")]))
        try await store.writeOpenTabs(snap(stopped, "Old Mac", []))
        try await store.writeOpenTabs(snap(stale, "Dusty", [tab("Gone", "https://gone.example")], at: Date().addingTimeInterval(-15 * 86_400)))

        let seenByB = try await store.readOtherOpenTabs(excluding: b)
        precondition(seenByB.count == 1 && seenByB[0].deviceName == "Studio", "B sees only the Mac that is sharing: \(seenByB.map(\.deviceName))")
        precondition(seenByB[0].tabs.map(\.title) == ["Apple", "Swift"] && seenByB[0].tabs[0].url == "https://apple.com", "tabs arrive whole and in order")
        let seenByA = try await store.readOtherOpenTabs(excluding: a)
        precondition(seenByA.map(\.deviceName) == ["Laptop"], "A sees B, never itself, an empty list or a stale one")

        try await store.writeOpenTabs(snap(a, "Studio", []))
        let afterStop = try await store.readOtherOpenTabs(excluding: b)
        precondition(afterStop.isEmpty, "a Mac that stops sharing drops out")

        // Sealed lists: the full address crosses, the folder holds no readable address, a Mac without the key sees nothing.
        let key = SymmetricKey(size: .bits256), wrong = SymmetricKey(size: .bits256)
        let sealed = UUID(), reader = UUID()
        try await store.writeOpenTabs(snap(sealed, "Sealed", [tab("Doc", "https://docs.example/d/abc?token=SECRET")]), key: key)
        let files = try await store.list("openTabs").names
        for name in files where name.hasPrefix(sealed.uuidString) {
            let raw = try await store.get("openTabs/\(name)") ?? Data()
            precondition(!String(decoding: raw, as: UTF8.self).contains("SECRET"), "no file in the folder shows the address: \(name)")
        }
        let withKey = try await store.readOtherOpenTabs(excluding: reader, key: key)
        precondition(withKey.contains { $0.deviceName == "Sealed" && $0.tabs[0].url.contains("token=SECRET") }, "the right key opens the full address")
        let withoutKey = try await store.readOtherOpenTabs(excluding: reader, key: wrong)
        precondition(!withoutKey.contains { $0.deviceName == "Sealed" }, "a wrong key shows nothing")

        // A sealed list altered in the folder is refused, and the other lists still arrive.
        let sealedName = files.first { $0.hasPrefix(sealed.uuidString) && $0.hasSuffix(".enc") }!
        var bytes = try await store.get("openTabs/\(sealedName)")!
        bytes[bytes.count / 2] ^= 0xFF
        try await store.put("openTabs/\(sealedName)", bytes)
        let afterTamper = try await store.readOtherOpenTabs(excluding: reader, key: key)
        precondition(!afterTamper.contains { $0.deviceName == "Sealed" }, "a list changed in the folder shows nothing")
        precondition(afterTamper.contains { $0.deviceName == "Laptop" }, "and does not hide the others")
        print("OpenTabsSync ok: shared lists reach the other Mac, and only those")
    }
}
