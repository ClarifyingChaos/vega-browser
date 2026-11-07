// Licensed under GPL-3.0. See LICENSE.
//
//  BrowserManager+VegaURL.swift
//  Vega
//

import AppKit
import VegaWeb
import OSLog

private let vegaURLLog = Logger(subsystem: "com.gstudios.vega", category: "VegaURL")

extension BrowserManager {
    /// Runs a vega:// link from another app. Dropped unless Settings > Links allows it.
    func handleVegaURL(_ link: URL) {
        guard vegaSettings?.allowVegaURLs == true else {
            vegaURLLog.info("Dropped vega:// link: not allowed in Settings")
            return
        }
        guard let command = VegaURLCommand.parse(link) else {
            vegaURLLog.info("Ignored vega:// link: \(link.host ?? "", privacy: .public) is not a valid command")
            return
        }
        if !command.ignored.isEmpty {
            vegaURLLog.info("Ignored vega:// parameters: \(command.ignored.joined(separator: ","), privacy: .public)")
        }

        var spaceID: UUID?
        if let name = command.space {
            let choices = tabs.orderedSpaces.filter { !$0.isAgent }.map { (id: $0.id, name: $0.name) }
            guard let match = VegaURLCommand.match(name, in: choices) else {
                vegaURLLog.info("Ignored vega:// link: no such space")
                return
            }
            spaceID = match
        }
        guard let window = openBrowserWindow(), !window.isIncognito else { return }
        // A window showing the Agent space opens into the first ordinary one.
        if spaceID == nil, window.spaceID.flatMap({ tabs.space($0) })?.isAgent == true {
            spaceID = tabs.orderedSpaces.first { !$0.isAgent }?.id
        }

        switch command.action {
        case .switchSpace:
            if let spaceID { tabs.setSpace(spaceID, in: window) }
        case .open(let url, let reuse):
            openFromLauncher(url, reuse: reuse, space: spaceID, explicit: command.space != nil, in: window)
        case .search(let query):
            guard let template = vegaSettings?.resolvedSearchEngineTemplate,
                  let url = VegaURLCommand.searchURL(for: query, template: template) else { return }
            openFromLauncher(url, reuse: false, space: spaceID, explicit: command.space != nil, in: window)
        }
    }

    private func openFromLauncher(_ url: URL, reuse: Bool, space: UUID?, explicit: Bool, in window: BrowserWindowState) {
        if reuse, let target = space ?? window.spaceID,
           let existing = tabs.items(inSpace: target).first(where: { $0.url.map { VegaURLCommand.isSamePage($0, url) } == true }) {
            tabs.select(existing.id, in: window)
            return
        }
        // Air Traffic Control only decides when the link names no space.
        if !explicit, siteRoutingManager.applyRoute(url: url, from: nil) { return }
        tabs.open(url: url, in: window, placement: .newTab, parent: space.map { .tabs(spaceID: $0) })
    }
}
