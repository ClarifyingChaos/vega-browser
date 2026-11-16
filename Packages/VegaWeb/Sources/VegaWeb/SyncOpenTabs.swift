// Licensed under GPL-3.0. See LICENSE.
//
//  SyncOpenTabs.swift
//  VegaWeb
//
//  FORK: this Mac's open tabs, for `SyncCoordinator`. The files and their format are in SyncOpenTabsStore.swift.
//

import Foundation
import VegaTabsCore

extension SyncCoordinator {
    /// Every web tab open in this Mac's spaces (the Agent space and private windows are never listed).
    /// `keepFullAddresses` only when the list will be sealed; plain text loses query strings, fragments and logins.
    func ownOpenTabs(in tabs: TabsController, profile: UUID? = nil, keepFullAddresses: Bool = false) -> [OpenTabsSnapshot.Entry] {
        var out: [OpenTabsSnapshot.Entry] = []
        // Only this profile's spaces: another profile's tabs belong to another account.
        for space in tabs.spaces(ofProfile: profile) where !space.isAgent {
            for id in tabs.displayOrder(inSpace: space.id) {
                let session = tabs.session(for: id)
                guard let url = session?.url ?? tabs.item(id)?.url, ["http", "https"].contains(url.scheme?.lowercased()) else { continue }
                let title = session?.title.isEmpty == false ? session!.title : (tabs.item(id)?.displayTitle ?? url.host() ?? "")
                // The folder is plain text in iCloud or Drive, so keep tokens and search terms out of it.
                guard let clean = keepFullAddresses ? url : OpenTabsSnapshot.clean(url) else { continue }
                out.append(.init(title: title, url: clean.absoluteString, space: space.name))
            }
        }
        return Array(out.prefix(200))
    }
}
