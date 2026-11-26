// Licensed under GPL-3.0. See LICENSE.
//
//  BrowserManager+Import.swift
//  Nook
//

import AppKit
import Foundation
import OSLog
import UniformTypeIdentifiers
import NookTabsCore
import NookWeb
import SwiftUI

extension BrowserManager {
    /// Arc's spaces in order, each with its pinned and Today sections, its profile's favorites,
    /// nested folders, custom tab names and theme color. Each Arc profile becomes a Nook profile
    /// with Arc's name. Arc's member card is kept beside the tabs. Air Traffic Control rules and the last 30 days of archived tabs come over too.
    /// Returns what came in as a sentence, or nil when no space did.
    @discardableResult
    func importArcData() async -> String? {
        let result = await importManager.importArcSidebarData()
        if let card = importManager.arcMembershipCard() {
            try? card.write(to: TabsController.defaultDirectory.deletingLastPathComponent()
                .appendingPathComponent("ArcMembershipCard.json"), options: .atomic)
        }
        guard let window = importWindow else { return nil }
        // Onboarding starts with one space holding a Google tab; beside Arc's spaces it is only an extra.
        let starters = nookSettings?.didFinishOnboarding == false
            ? tabs.orderedSpaces.filter { space in
                !space.isAgent && tabs.items(inSpace: space.id).allSatisfy {
                    $0.parent == .tabs(spaceID: space.id) && $0.url?.host == TabsController.homeURL.host
                }
            }.map(\.id) : []

        var lastSpace = tabs.orderedSpaces.last?.id
        var firstImported: UUID?
        var profileSpaces: [String: UUID] = [:]
        var arcSpaceIDs: [String: UUID] = [:]
        var tabCount = 0, folderCount = 0
        for space in result.spaces {
            guard let spaceID = tabs.createSpace(
                name: space.title, icon: space.emoji ?? "",
                accentHex: space.accentHex ?? "#7C7C7C", after: lastSpace,
                sharingLoginsWith: profileSpaces[space.profile],
                profileName: result.profileNames[space.profile]
            ) else { continue }
            lastSpace = spaceID
            arcSpaceIDs[space.id] = spaceID
            firstImported = firstImported ?? spaceID
            if profileSpaces[space.profile] == nil { profileSpaces[space.profile] = spaceID }

            // Arc shows a profile's favorites in each of its spaces; a Nook space has its own.
            importArc(result.favorites[space.profile] ?? [], into: .favorites(spaceID: spaceID), window: window, tabs: &tabCount, folders: &folderCount)
            importArc(space.pinned, into: .pinned(spaceID: spaceID), window: window, tabs: &tabCount, folders: &folderCount)
            importArc(space.unpinned, into: .tabs(spaceID: spaceID), window: window, tabs: &tabCount, folders: &folderCount)
            tabs.setAllFolders(open: false, space: spaceID)
        }

        guard let firstImported else { return nil }
        if window.spaceID.map(starters.contains) ?? true { tabs.setSpace(firstImported, in: window) }
        starters.forEach { tabs.deleteSpace($0) }

        let routes = arcSiteRules(result.routing, spaceIDs: arcSpaceIDs, existing: nookSettings?.siteRoutingRules ?? [])
        nookSettings?.siteRoutingRules += routes.rules
        let archived = tabs.importArchive(arcArchiveEntries(result.archive, spaceIDs: arcSpaceIDs, existing: tabs.archive.entries))
        nookSettings?.didImportFromArc = true
        Self.importLog.notice("Arc import: \(routes.rules.count) routing rules added, \(routes.skipped) skipped, \(archived) archived tabs")
        return arcImportSummary(spaces: arcSpaceIDs.count, tabs: tabCount, folders: folderCount, rules: routes.rules.count, archived: archived)
    }

    /// Returns what came in as a sentence, or nil when nothing did.
    @discardableResult
    func importDiaData() async -> String? {
        let result = await importManager.importDiaData()
        let count = result.favoriteTabs.count + result.windowTabs.count
        guard count > 0, let window = importWindow, let spaceID = importSpaceID(window) else { return nil }

        importTabs(result.favoriteTabs.map(\.url), into: .favorites(spaceID: spaceID), window: window)
        importTabs(result.windowTabs.map(\.url), into: .tabs(spaceID: spaceID), window: window)
        return "\(count) \(count == 1 ? "tab" : "tabs")"
    }

    // MARK: - Chrome

    /// Bookmarks go into a space of their own, signed in as the space in front, so one delete undoes them.
    /// History is read off the main thread. Returns what came in, as a sentence.
    func importChrome(_ profile: ChromeProfile, bookmarks: Bool, history: Bool) async -> String {
        var parts: [String] = []
        if bookmarks {
            let file = profile.directory.appendingPathComponent("Bookmarks")
            let tree = await Task.detached { (try? Data(contentsOf: file)).map(parseChromeBookmarks) ?? [] }.value
            if !tree.isEmpty, let window = importWindow,
               let spaceID = tabs.createSpace(name: "Chrome", icon: "", accentHex: "#7C7C7C", after: tabs.orderedSpaces.last?.id,
                                              sharingLoginsWith: importSpaceID(window)) {
                var tabCount = 0, folderCount = 0
                importArc(tree.map(Self.node), into: .pinned(spaceID: spaceID), window: window, tabs: &tabCount, folders: &folderCount)
                tabs.setAllFolders(open: false, space: spaceID)
                tabs.setSpace(spaceID, in: window)
                parts.append("\(tabCount.formatted()) \(tabCount == 1 ? "bookmark" : "bookmarks") in \(folderCount.formatted()) \(folderCount == 1 ? "folder" : "folders")")
            } else {
                parts.append("no bookmarks found")
            }
        }
        if history {
            let directory = profile.directory
            if let visits = await Task.detached(operation: { chromeHistory(profile: directory) }).value {
                let profileID = historyManager.currentProfileId
                historyManager.importVisits(visits.map {
                    HistoryVisit(url: $0.url, title: $0.title, timestamp: $0.date, tabId: nil, profileId: profileID)
                })
                parts.append("\(visits.count.formatted()) history \(visits.count == 1 ? "entry" : "entries")")
            } else {
                parts.append("history couldn\u{2019}t be read")
            }
        }
        return parts.isEmpty ? "Choose your extensions next." : parts.joined(separator: " \u{00B7} ")
    }

    private static func node(_ node: ChromeNode) -> ArcNode {
        switch node {
        case let .bookmark(url, title): .tab(url: url, title: title.isEmpty ? nil : title, customTitle: title.isEmpty ? nil : title)
        case let .folder(title, children): .folder(title: title, children: children.map(Self.node))
        }
    }

    func chromeExtensionChoices(_ profile: ChromeProfile) async -> [ExtensionChoice] {
        guard let manager = extensionManager, manager.isExtensionSupportAvailable else { return [] }
        return manager.choices(from: importManager.chromeExtensions(profile))
    }

    /// Asks for a passwords file exported from another browser and saves its logins to the front window's
    /// profile. Returns what happened, or nil when the person chose no file.
    func importPasswordFile(trashAfter: Bool) -> String? {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.commaSeparatedText, .plainText]
        panel.message = "Choose the passwords file you exported."
        guard panel.runModal() == .OK, let url = panel.url else { return nil }
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return "Vega couldn\u{2019}t read that file." }
        let result = PasswordCSV.parse(text)
        guard !result.rows.isEmpty else { return "No passwords found in that file, so it was left where it is." }
        let vault = KeychainVault.forProfile(windowRegistry?.mostRecentRegularWindow.flatMap { tabs.profileID(of: $0) })
        for row in result.rows { vault.save(host: row.host, username: row.username, password: row.password) }
        // The vault reports no failure, so each login is read back before the file may go. A later row wins.
        let wanted = Dictionary(result.rows.map { ([$0.host, $0.username], $0.password) }, uniquingKeysWith: { $1 })
        let lost = wanted.filter { vault.password(host: $0.key[0], username: $0.key[1]) != $0.value }.count
        guard lost == 0 else {
            return "\(lost) of \(wanted.count) passwords couldn\u{2019}t be saved, so the file was left where it is."
        }
        var message = "Imported \(result.rows.count) \(result.rows.count == 1 ? "password" : "passwords")"
        if result.skipped > 0 { message += ", skipped \(result.skipped) without a site, user or password" }
        guard trashAfter else { return message + ". Delete the file: it holds your passwords as plain text." }
        do {
            try FileManager.default.trashItem(at: url, resultingItemURL: nil)
            return message + ". The file is in the Trash."
        } catch {
            return message + ". The file couldn\u{2019}t be moved to the Trash, so delete it yourself."
        }
    }

    func importSafariData(from directoryURL: URL, importBookmarks: Bool, importHistory: Bool) async {
        let result = await importManager.importSafariData(
            from: directoryURL,
            importBookmarks: importBookmarks,
            importHistory: importHistory
        )

        if !result.bookmarks.isEmpty, let window = importWindow, let spaceID = importSpaceID(window) {
            let favoritesBookmarks = result.bookmarks.filter { $0.folder == "Favorites" }
            let otherBookmarks = result.bookmarks.filter { $0.folder != "Favorites" }

            importTabs(favoritesBookmarks.map(\.url), into: .favorites(spaceID: spaceID), window: window)

            var folderGroups: [String: [SafariBookmark]] = [:]
            var unfolderedBookmarks: [SafariBookmark] = []
            for bookmark in otherBookmarks {
                if let folder = bookmark.folder, !folder.isEmpty {
                    folderGroups[folder, default: []].append(bookmark)
                } else {
                    unfolderedBookmarks.append(bookmark)
                }
            }

            importTabs(unfolderedBookmarks.map(\.url), into: .tabs(spaceID: spaceID), window: window)
            for (folderName, bookmarks) in folderGroups.sorted(by: { $0.key > $1.key }) {
                guard let folderID = tabs.createFolder(title: folderName, in: .pinned(spaceID: spaceID), after: nil) else { continue }
                importTabs(bookmarks.map(\.url), into: .folder(itemID: folderID), window: window)
            }
        }

        if !result.history.isEmpty {
            let profileId = historyManager.currentProfileId
            historyManager.importVisits(result.history.compactMap { entry in
                guard let url = URL(string: entry.url) else { return nil }
                return HistoryVisit(url: url, title: entry.title, timestamp: entry.visitDate,
                                    tabId: nil, profileId: profileId)
            })
        }
    }

    /// The extensions to offer after an import: Arc's when it was the source, and the Safari
    /// extensions from apps on this Mac.
    func extensionChoices(includingArc: Bool) async -> [ExtensionChoice] {
        guard let manager = extensionManager, manager.isExtensionSupportAvailable else { return [] }
        await manager.refreshSafariExtensions()
        let arc = includingArc ? importManager.arcExtensions() : []
        return manager.choices(from: arc + (manager.safariExtensions ?? []).map(ExtensionOffer.init))
    }

    private static let importLog = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Nook", category: "Import")

    // MARK: - Helpers

    /// A regular window: intents need one to pick the main tree. Imports never go to a private
    /// window. Onboarding imports run before any browser window registers; an unregistered window
    /// state still targets the main tree, and background opens never select in it.
    private var importWindow: BrowserWindowState? {
        windowRegistry?.mostRecentRegularWindow ?? BrowserWindowState()
    }

    private func importSpaceID(_ window: BrowserWindowState) -> UUID? {
        window.spaceID ?? tabs.orderedSpaces.first?.id
    }

    /// Adds Arc's tree under `parent` in source order. A folder Nook cannot hold there (in
    /// favorites, or past the depth limit) gives its tabs to the parent instead.
    private func importArc(_ nodes: [ArcNode], into parent: Parent, window: BrowserWindowState,
                           tabs tabCount: inout Int, folders folderCount: inout Int) {
        for node in nodes.reversed() {
            switch node {
            case let .tab(string, title, customTitle):
                guard let url = URL(string: string), ["http", "https", "file"].contains(url.scheme?.lowercased()),
                      let id = tabs.open(url: url, in: window, placement: .background, parent: parent, title: title)
                else { continue }
                tabCount += 1
                if let customTitle { tabs.rename(id, customTitle) }
            case let .folder(title, children):
                if let folderID = tabs.createFolder(title: title, in: parent, after: nil) {
                    folderCount += 1
                    importArc(children, into: .folder(itemID: folderID), window: window, tabs: &tabCount, folders: &folderCount)
                } else {
                    importArc(children, into: parent, window: window, tabs: &tabCount, folders: &folderCount)
                }
            }
        }
    }

    /// Adds tabs under `parent` in source order without loading pages or changing selection.
    /// `open` inserts at the top, so the list goes in reversed.
    private func importTabs(_ urls: [String], into parent: Parent, window: BrowserWindowState) {
        for string in urls.reversed() {
            guard let url = URL(string: string), url.scheme != nil else { continue }
            tabs.open(url: url, in: window, placement: .background, parent: parent)
        }
    }
}
