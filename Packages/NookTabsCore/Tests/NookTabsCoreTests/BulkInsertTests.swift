import Foundation
import Testing
@testable import NookTabsCore

@Suite struct BulkInsertTests {
    private func tab(_ n: Int) -> NewItem { .tab(url: URL(string: "https://e\(n).test/")!, title: "t\(n)", customTitle: nil) }
    private func names(_ tree: TabTree, _ parent: Parent) -> [String] { tree.children(of: parent).map(\.displayTitle) }

    @Test func keepsOrderAboveWhatWasThereWithFoldersInside() throws {
        var f = Fixture()
        let parent = Parent.pinned(spaceID: f.spaceA)
        f.tab("old", in: parent)
        let result = try f.tree.insert([tab(1), .folder(title: "F", children: [tab(2), tab(3)]), tab(4)], in: parent)
        #expect(result.tabs == 4 && result.folders == 1)
        #expect(names(f.tree, parent) == ["t1", "F", "t4", "old"])
        let folder = f.tree.children(of: parent)[1]
        #expect(names(f.tree, .folder(itemID: folder.id)) == ["t2", "t3"])
    }

    @Test func favoritesTakeAFoldersTabs() throws {
        var f = Fixture()
        let parent = Parent.favorites(spaceID: f.spaceA)
        let result = try f.tree.insert([.folder(title: "F", children: [tab(1), tab(2)]), tab(3)], in: parent)
        #expect(result.folders == 0 && names(f.tree, parent) == ["t1", "t2", "t3"])
    }

    @Test func tooDeepFoldersFlattenAndNothingIsLost() throws {
        var f = Fixture()
        var node = tab(0)
        for depth in 0..<20 { node = .folder(title: "d\(depth)", children: [node]) }
        let result = try f.tree.insert([node], in: .pinned(spaceID: f.spaceA))
        #expect(result.tabs == 1 && result.folders == TabTree.maxFolderDepth)
    }

    @Test(.timeLimit(.minutes(1))) func thousandsAreQuickShortKeyedAndOneUndo() throws {
        var f = Fixture()
        let parent = Parent.pinned(spaceID: f.spaceA)
        let start = Date()
        let result = try f.tree.insert((0..<20_000).map(tab), in: parent)
        #expect(Date().timeIntervalSince(start) < 5)
        let children = f.tree.children(of: parent)
        #expect(children.count == 20_000 && children.map(\.displayTitle) == (0..<20_000).map { "t\($0)" })
        #expect(children.allSatisfy { $0.order.rawValue.count < 12 })
        #expect(result.change.items.count == 20_000)
    }
}
