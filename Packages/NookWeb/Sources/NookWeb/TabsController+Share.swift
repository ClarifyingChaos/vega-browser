// Licensed under GPL-3.0. See LICENSE.
//
//  TabsController+Share.swift
//  NookWeb
//
//  FORK: a space as a file other people can open: its name and look, its favorites, pinned tabs, folders and
//  tabs, as titles and web addresses. No logins, history or page data travel with it. Opening one makes a new
//  space; nothing in it loads until it is clicked.
//

import Foundation
import NookTabsCore

public extension TabsController {
    /// The space as a file's content. Only web addresses are kept.
    func sharedSpace(_ spaceID: UUID) -> SharedSpace? {
        guard let space = space(spaceID), !space.isAgent else { return nil }
        func nodes(_ parent: Parent) -> [SharedSpace.Node] {
            children(of: parent).compactMap { item in
                if item.isFolder { return .init(title: item.displayTitle, children: nodes(.folder(itemID: item.id))) }
                guard let url = item.url, ["http", "https"].contains(url.scheme?.lowercased()) else { return nil }
                return .init(title: item.displayTitle, url: url.absoluteString)
            }
        }
        return SharedSpace(name: space.name, icon: space.icon, accentHex: space.accentHex,
                           favorites: nodes(.favorites(spaceID: spaceID)), pinned: nodes(.pinned(spaceID: spaceID)),
                           tabs: nodes(.tabs(spaceID: spaceID)))
    }

    /// Reads a shared space from file data, nil when it is not one or is from a newer format.
    static func decodeSharedSpace(_ data: Data) -> SharedSpace? {
        guard data.count < 4_000_000, let shared = try? JSONDecoder().decode(SharedSpace.self, from: data),
              shared.format <= SharedSpace.formatVersion else { return nil }
        return shared
    }

    /// Makes a new space from a shared one, at the end of the space list. Returns its id.
    @discardableResult
    func importSharedSpace(_ shared: SharedSpace) -> UUID? {
        var budget = SharedSpace.limit
        let name = String(shared.name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(60))
        guard let spaceID = createSpace(name: name.isEmpty ? "Shared Space" : name, icon: shared.icon.isEmpty ? "circle.fill" : String(shared.icon.prefix(40)),
                                        accentHex: shared.accentHex.count == 6 || shared.accentHex.count == 7 ? shared.accentHex : "7A5CFF",
                                        after: orderedSpaces.last?.id),
              let owner = owner(ofSpace: spaceID) else { return nil }
        func add(_ nodes: [SharedSpace.Node], to parent: Parent) {
            var after: UUID?
            for node in nodes where budget > 0 {
                budget -= 1
                let title = String(node.title.prefix(SharedSpace.titleLimit))
                let id = UUID()
                if let text = node.url {
                    guard let url = URL(string: text), ["http", "https"].contains(url.scheme?.lowercased()), url.host != nil else { continue }
                    if perform(owner, "import tab", undoable: false, { try $0.createTab(id: id, url: url, title: title, in: parent, after: after) }) != nil { after = id }
                } else if perform(owner, "import folder", undoable: false, { try $0.createFolder(id: id, title: title, in: parent, after: after) }) != nil {
                    after = id
                    add(node.children, to: .folder(itemID: id))
                }
            }
        }
        add(shared.favorites, to: .favorites(spaceID: spaceID))
        add(shared.pinned, to: .pinned(spaceID: spaceID))
        add(shared.tabs, to: .tabs(spaceID: spaceID))
        return spaceID
    }
}
