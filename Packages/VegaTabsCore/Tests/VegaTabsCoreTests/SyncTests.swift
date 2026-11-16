// Licensed under GPL-3.0. See LICENSE.
import Foundation
import Testing
@testable import VegaTabsCore

struct SyncTests {
    let macA = UUID(), macB = UUID()
    let later = fixedNow.addingTimeInterval(60)

    /// What each Mac does on a tick: read the other's file, apply what is newer.
    func exchange(_ a: inout TabTree, _ b: inout TabTree) {
        let sa = SyncMerge.snapshot(of: a, deviceID: macA, deviceName: "A", now: later)
        let sb = SyncMerge.snapshot(of: b, deviceID: macB, deviceName: "B", now: later)
        a.apply(SyncMerge.change(applying: sb, to: a))
        b.apply(SyncMerge.change(applying: sa, to: b))
    }

    @Test func aFavoriteAddedOnOneMacReachesTheOther() throws {
        var f = Fixture()
        var other = f.tree
        f.tab("one", in: .favorites(spaceID: f.spaceA))
        exchange(&f.tree, &other)
        #expect(other.favorites(of: f.spaceA).map(\.displayTitle) == ["one"])
    }

    @Test func openTabsTravelWhenAskedAndAClosedOneIsClosedOnTheOtherMac() throws {
        var f = Fixture()
        let tab = f.tab("open", in: .tabs(spaceID: f.spaceA))
        var other = f.tree

        #expect(!SyncMerge.snapshot(of: f.tree, deviceID: macA, deviceName: "A", now: later).items.contains { $0.id == tab }, "off: a tab stays on its Mac")
        let with = SyncMerge.snapshot(of: f.tree, deviceID: macA, deviceName: "A", includeTabs: true, now: later)
        #expect(with.items.contains { $0.id == tab }, "on: the tab is in the snapshot")

        var empty = TabTree(spaces: Array(f.tree.spaces.values), items: [])
        empty.apply(SyncMerge.change(applying: with, to: empty))
        #expect(empty.item(tab)?.displayTitle == "open", "the other Mac gets the tab")

        // Closed on A: the deletion reaches B.
        _ = try f.tree.close(tab, now: later.addingTimeInterval(5))
        let closed = SyncMerge.snapshot(of: f.tree, deviceID: macA, deviceName: "A", includeTabs: true, now: later.addingTimeInterval(6))
        #expect(closed.items.contains { $0.id == tab && $0.deletedAt != nil }, "the closing travels")
        other.apply(SyncMerge.change(applying: closed, to: other))
        #expect(other.item(tab) == nil || other.item(tab)?.deletedAt != nil, "and the tab is gone on the other Mac")

        // A week later the closing is forgotten, so the files do not collect every tab ever closed.
        let old = SyncMerge.snapshot(of: f.tree, deviceID: macA, deviceName: "A", includeTabs: true, now: later.addingTimeInterval(8 * 86_400))
        #expect(!old.items.contains { $0.id == tab }, "an old closed tab drops out after a week")
    }

    @Test func aProfilesSnapshotHoldsOnlyItsOwnSpacesAndTabs() throws {
        var f = Fixture()
        let store = UUID(), otherStore = UUID()
        let mine = UUID(), theirs = UUID()
        f.tree.createSpace(id: mine, name: "Mine", icon: "m", accentHex: "#111", after: f.spaceB, dataStoreID: store, now: later)
        f.tree.createSpace(id: theirs, name: "Theirs", icon: "t", accentHex: "#222", after: mine, dataStoreID: otherStore, now: later)
        let myTab = f.tab("mine", in: .pinned(spaceID: mine))
        let theirTab = f.tab("theirs", in: .pinned(spaceID: theirs))

        let snapshot = SyncMerge.snapshot(of: f.tree, deviceID: macA, deviceName: "A", profile: store, now: later)
        #expect(snapshot.spaces.map(\.id) == [mine], "only the profile's own space travels to its account")
        #expect(snapshot.items.map(\.id) == [myTab], "and only what is in it")
        #expect(!snapshot.items.contains { $0.id == theirTab })

        // A space deleted when its profile was merged away still travels, so the other Mac drops it too; a deleted
        // space of a profile that still exists does not (that profile's own account carries it).
        let gone = UUID(), goneStore = UUID(), keptDeleted = UUID()
        f.tree.createSpace(id: gone, name: "Old", icon: "o", accentHex: "#333", after: theirs, dataStoreID: goneStore, now: later)
        f.tree.createSpace(id: keptDeleted, name: "Mine too", icon: "k", accentHex: "#444", after: gone, dataStoreID: otherStore, now: later)
        _ = try f.tree.deleteSpace(gone, now: later)
        _ = try f.tree.deleteSpace(keptDeleted, now: later)
        let withDeletions = SyncMerge.snapshot(of: f.tree, deviceID: macA, deviceName: "A", profile: store, now: later)
        #expect(withDeletions.spaces.contains { $0.id == gone && $0.deletedAt != nil }, "the deletion of a merged-away space travels")
        #expect(!withDeletions.spaces.contains { $0.id == keptDeleted }, "another live profile's deletion stays with it")
        #expect(!withDeletions.spaces.contains { $0.id == theirs }, "and its live space still does")

        let everything = SyncMerge.snapshot(of: f.tree, deviceID: macA, deviceName: "A", now: later)
        #expect(everything.spaces.count == f.tree.spaces.count - (f.tree.spaces.values.filter(\.isAgent).count), "no profile asked for: every space, as before")
    }

    @Test func aNewSpaceReachesTheOther() throws {
        var f = Fixture()
        var other = f.tree
        let id = UUID()
        f.tree.createSpace(id: id, name: "Work", icon: "w", accentHex: "#123", after: f.spaceB, now: later)
        exchange(&f.tree, &other)
        #expect(other.space(id)?.name == "Work")
    }

    @Test func theNewerEditWins() throws {
        var f = Fixture()
        let tab = f.tab("x", in: .pinned(spaceID: f.spaceA))
        var other = f.tree
        try f.tree.rename(tab, customTitle: "older", now: later)
        try other.rename(tab, customTitle: "newer", now: later.addingTimeInterval(5))
        exchange(&f.tree, &other)
        #expect(f.tree.item(tab)?.customTitle == "newer")
        #expect(other.item(tab)?.customTitle == "newer")
    }

    @Test func aDeletionTravelsAndDoesNotComeBack() throws {
        var f = Fixture()
        let tab = f.tab("gone", in: .favorites(spaceID: f.spaceA))
        var other = f.tree
        try f.tree.close(tab, now: later)
        exchange(&f.tree, &other)
        #expect(other.item(tab) == nil)
        exchange(&f.tree, &other)
        #expect(f.tree.item(tab) == nil && other.item(tab) == nil)
    }

    @Test func openTabsStayOnTheirMac() throws {
        var f = Fixture()
        var other = f.tree
        let open = f.tab("open", in: .tabs(spaceID: f.spaceA))
        exchange(&f.tree, &other)
        #expect(other.item(open) == nil)
    }

    @Test func twoMacsThatExchangedEverythingStopChanging() throws {
        var f = Fixture()
        var other = f.tree
        f.tab("a", in: .favorites(spaceID: f.spaceA))
        f.tab("b", in: .pinned(spaceID: f.spaceB))
        exchange(&f.tree, &other)
        let again = SyncMerge.change(applying: SyncMerge.snapshot(of: f.tree, deviceID: macA, deviceName: "A", now: later), to: other)
        #expect(again.isEmpty)
    }

    @Test func oldTombstonesAreLeftOut() throws {
        var f = Fixture()
        let tab = f.tab("old", in: .favorites(spaceID: f.spaceA))
        try f.tree.close(tab, now: fixedNow)
        let snap = SyncMerge.snapshot(of: f.tree, deviceID: macA, deviceName: "A", now: fixedNow.addingTimeInterval(40 * 86_400))
        #expect(!snap.items.contains { $0.id == tab })
    }

    @Test func folderRoundTripAndBadFiles() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("sync-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: dir) }
        var f = Fixture()
        f.tab("one", in: .favorites(spaceID: f.spaceA))
        let store = FolderBlobStore(url: dir)
        try await store.writeSnapshot(SyncMerge.snapshot(of: f.tree, deviceID: macA, deviceName: "A", now: later))
        try await store.put("devices/junk.json", Data("not json".utf8))
        let read = try await store.readOtherSnapshots(excluding: macB)
        #expect(read.snapshots.count == 1 && read.snapshots[0].deviceID == macA)
        let own = try await store.readOtherSnapshots(excluding: macA)
        #expect(own.snapshots.isEmpty, "never reads its own file")
    }
}
