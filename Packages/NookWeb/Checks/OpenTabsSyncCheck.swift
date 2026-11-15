// Licensed under GPL-3.0. See LICENSE.
//
//  OpenTabsSyncCheck.swift
//  Nook
//
//  Two Macs sharing a folder: each sees the other's open tabs and never its own, a Mac that stopped
//  sharing (an empty list) and one not heard from in two weeks drop out. Compiles the shipped sources:
//
//    swiftc Packages/NookTabsCore/Sources/NookTabsCore/*.swift \
//           Packages/NookWeb/Sources/NookWeb/SyncOpenTabsStore.swift \
//           Packages/NookWeb/Checks/OpenTabsSyncCheck.swift -o /tmp/open-tabs-sync-check && /tmp/open-tabs-sync-check
//

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
        print("OpenTabsSync ok: shared lists reach the other Mac, and only those")
    }
}
