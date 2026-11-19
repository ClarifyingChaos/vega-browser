// Licensed under GPL-3.0. See LICENSE.
//
//  OtherMacsTabsMenu.swift
//  Nook
//
//  FORK: the tabs open on your other Macs, as a menu: the menu bar's Spaces › Tabs from Other Macs and the sidebar's
//  right-click menu share it.
//

import SwiftUI
import NookWeb

struct OtherMacsTabsMenu: View {
    @EnvironmentObject private var browserManager: BrowserManager
    @Environment(BrowserWindowState.self) private var windowState

    var body: some View {
        let sync = SyncCoordinator.forProfile(browserManager.tabs.profileID(of: windowState))
        Menu {
            if !sync.isEnabled || !sync.sharesOpenTabs {
                Button("Turn On Sharing in Settings…") { browserManager.openSettings(tab: .general) }
            } else if sync.otherMacsTabs.isEmpty {
                Text("No other Mac is sharing tabs yet")
            } else {
                ForEach(sync.otherMacsTabs) { mac in
                    Menu(mac.deviceName) {
                        ForEach(mac.tabs) { tab in
                            Button(tab.title.isEmpty ? tab.url : tab.title) {
                                if let url = URL(string: tab.url) { _ = browserManager.tabs.open(url: url, in: windowState, placement: .newTab) }
                            }
                        }
                    }
                }
            }
        } label: {
            Label("Tabs from Other Macs", nookIcon: "laptopcomputer.and.iphone")
        }
    }
}
