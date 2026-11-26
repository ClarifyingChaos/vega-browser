// Licensed under GPL-3.0. See LICENSE.
import Foundation
import Testing
@testable import NookTabsCore

/// Live folders are gone, but a folder saved or synced with a source must keep it and stay a folder.
struct FormerLiveFolderTests {
    @Test func sourceSurvivesSavingAndAnOlderDeviceFileStillLoads() throws {
        let space = UUID()
        let folder = Item(parent: .pinned(spaceID: space), order: OrderKey.between(nil, nil)!, kind: .folder,
                          customTitle: "Pull Requests", live: LiveSource(rawValue: "githubPulls"))
        let back = try JSONDecoder().decode(Item.self, from: JSONEncoder().encode(folder))
        #expect(back.isFolder && back.live?.rawValue == "githubPulls")

        var device = try JSONSerialization.jsonObject(with: JSONEncoder().encode(DeviceState())) as! [String: Any]
        device["liveDismissed"] = [String: Any]()
        _ = try JSONDecoder().decode(DeviceState.self, from: JSONSerialization.data(withJSONObject: device))
    }
}
