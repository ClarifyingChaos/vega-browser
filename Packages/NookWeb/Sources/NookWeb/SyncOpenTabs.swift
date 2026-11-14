// Licensed under GPL-3.0. See LICENSE.
//
//  SyncOpenTabs.swift
//  NookWeb
//
//  FORK: this Mac's open tabs, for `SyncCoordinator`. The files and their format are in SyncOpenTabsStore.swift.
//

import Foundation
import NookTabsCore

extension SyncCoordinator {
    /// Every web tab open in this Mac's spaces (the Agent space and private windows are never listed).
    func ownOpenTabs(in tabs: TabsController) -> [OpenTabsSnapshot.Entry] {
        var out: [OpenTabsSnapshot.Entry] = []
        for space in tabs.orderedSpaces where !space.isAgent {
            for id in tabs.displayOrder(inSpace: space.id) {
                let session = tabs.session(for: id)
                guard let url = session?.url ?? tabs.item(id)?.url, ["http", "https"].contains(url.scheme?.lowercased()) else { continue }
                let title = session?.title.isEmpty == false ? session!.title : (tabs.item(id)?.displayTitle ?? url.host() ?? "")
                out.append(.init(title: title, url: url.absoluteString, space: space.name))
            }
        }
        return Array(out.prefix(200))
    }
}
