// Licensed under GPL-3.0. See LICENSE.
//
//  PaletteCommands.swift
//  Vega
//
//  FORK: what the command palette can do besides opening pages, as in Arc's command bar: type a command's name (or
//  ">" to list them all) and press Return.
//

import AppKit
import VegaWeb

struct PaletteCommand: Identifiable {
    let id: String
    let title: String
    let symbol: String
    var keywords: [String] = []
    /// Only for a web page in front.
    var needsPage = false
    let run: @MainActor (BrowserManager, BrowserWindowState) -> Void

    func matches(_ words: [Substring]) -> Bool {
        let haystack = ([title] + keywords).joined(separator: " ")
        return words.allSatisfy { haystack.localizedCaseInsensitiveContains($0) }
    }
}

@MainActor
enum PaletteCommands {
    static func all(_ m: BrowserManager) -> [PaletteCommand] {
        var list: [PaletteCommand] = [
            .init(id: "easel.new", title: "New Easel", symbol: "scribble.variable", keywords: ["canvas", "board"]) { _, _ in EaselManager.shared.newEasel() },
            .init(id: "easel.show", title: "Show Easels", symbol: "square.grid.2x2", keywords: ["canvas", "library"]) { m, _ in m.openLibrary(.easels) },
            .init(id: "note.new", title: "New Note", symbol: "note.text.badge.plus") { m, _ in m.newNote() },
            .init(id: "split.new", title: "Add Split View", symbol: "rectangle.split.2x1", keywords: ["side by side"]) { m, _ in m.addSplitView() },
            .init(id: "little", title: "New Little Window", symbol: "macwindow", keywords: ["mini"]) { m, _ in m.openLittleArcWindow() },
            .init(id: "capture", title: "Capture Visible Area", symbol: "camera.viewfinder", keywords: ["screenshot"], needsPage: true) { m, _ in m.capturePage(fullPage: false) },
            .init(id: "capture.full", title: "Capture Full Page", symbol: "camera.viewfinder", keywords: ["screenshot"], needsPage: true) { m, _ in m.capturePage(fullPage: true) },
            .init(id: "cast", title: "Cast Page", symbol: "airplayvideo", keywords: ["airplay", "tv"], needsPage: true) { m, _ in m.castPage() },
            .init(id: "pip", title: "Picture in Picture", symbol: "pip", keywords: ["video"], needsPage: true) { m, _ in m.tabs.activeWindowSession?.requestPictureInPicture() },
            .init(id: "translate", title: "Translate Page", symbol: "character.bubble", needsPage: true) { m, _ in m.tabs.activeWindowSession?.toggleTranslation() },
            .init(id: "reader", title: "Reader View", symbol: "doc.plaintext", keywords: ["read", "article"], needsPage: true) { m, _ in m.tabs.activeWindowSession?.toggleReader() },
            .init(id: "find", title: "Find in Page", symbol: "magnifyingglass", needsPage: true) { m, _ in m.showFindBar() },
            .init(id: "print", title: "Print Page", symbol: "printer", needsPage: true) { m, _ in m.printCurrentPage() },
            .init(id: "save", title: "Save Page As", symbol: "square.and.arrow.down", needsPage: true) { m, _ in m.savePageAs() },
            .init(id: "boost", title: "Boost This Site", symbol: "wand.and.stars", keywords: ["css", "style"], needsPage: true) { m, _ in m.boostCurrentSite() },
            .init(id: "sitecontrols", title: "Site Controls", symbol: "slider.horizontal.3", keywords: ["site settings", "permissions"]) { m, _ in m.toggleExtensionLibrary() },
            .init(id: "share.space", title: "Share Space", symbol: "square.and.arrow.up") { m, _ in m.shareSpace() },
            .init(id: "export.space", title: "Export Space", symbol: "square.and.arrow.up.on.square") { m, _ in m.exportSpace() },
            .init(id: "open.shared", title: "Open Shared Space", symbol: "tray.and.arrow.down") { m, _ in m.openSharedSpacePanel() },
            .init(id: "summarize", title: "Summarize Open Tabs", symbol: "text.append", keywords: ["ai"]) { m, _ in m.askVega("Summarize my open tabs.", task: .summarizeTabs) },
            .init(id: "browse", title: "Browse the Web for Me", symbol: "sparkles", keywords: ["ai", "agent"]) { m, _ in m.askVega(nil, task: .browse) },
            .init(id: "clear.today", title: "Clear Today", symbol: "xmark.bin", keywords: ["close tabs"]) { m, _ in m.clearToday() },
            .init(id: "library", title: "Show Library", symbol: "books.vertical") { _, w in LibraryMotion.present(w) },
            .init(id: "history", title: "Show History", symbol: "clock") { m, _ in m.openLibrary(.history) },
            .init(id: "downloads", title: "Show Downloads", symbol: "arrow.down.circle") { m, _ in m.openLibrary(.downloads) },
            .init(id: "media", title: "Show Media", symbol: "photo.on.rectangle") { m, _ in m.openLibrary(.media) },
            .init(id: "archive", title: "Show Archive", symbol: "archivebox") { m, _ in m.openLibrary(.archive) },
            .init(id: "taskmanager", title: "Task Manager", symbol: "gauge.with.dots.needle.33percent", keywords: ["memory", "sleep tabs", "performance"]) { m, _ in m.showTaskManager() },
            .init(id: "privacy", title: "Privacy Report", symbol: "hand.raised", keywords: ["trackers", "blocked", "dashboard"]) { m, _ in m.showPrivacyReport() },
            .init(id: "cleanup", title: "Privacy Cleanup", symbol: "sparkles.rectangle.stack", keywords: ["clear cookies"]) { m, _ in m.performPrivacyCleanup() },
            .init(id: "restore", title: "Restore Tabs from Backup", symbol: "clock.arrow.circlepath", keywords: ["backup", "spaces", "undo"]) { m, _ in m.openSettings(tab: .spaces) },
            .init(id: "passwords", title: "Passwords", symbol: "key", keywords: ["logins", "settings"]) { m, _ in m.openSettings(tab: .passwords) },
            .init(id: "sync", title: "Sync Settings", symbol: "arrow.triangle.2.circlepath", keywords: ["icloud", "google"]) { m, _ in m.openSettings(tab: .general) },
            .init(id: "permissions", title: "Site Permissions", symbol: "checkmark.shield", keywords: ["camera", "microphone", "location"]) { m, _ in m.openSettings(tab: .privacy) },
            .init(id: "tour", title: "Feature Tour", symbol: "sparkles.tv", keywords: ["help", "what's new"]) { m, _ in m.showFeatureTour() },
            .init(id: "updates", title: "Check for Updates", symbol: "arrow.down.app") { m, _ in m.appDelegate?.updaterController.checkForUpdates(nil) },
        ]
        // Pages on your other Macs, so "office" or a page's name finds them too.
        for mac in SyncCoordinator.shared.otherMacsTabs {
            for tab in mac.tabs.prefix(50) {
                guard let url = URL(string: tab.url) else { continue }
                list.append(.init(id: "othermac.\(mac.deviceID).\(tab.url)", title: "\(tab.title.isEmpty ? tab.url : tab.title) — on \(mac.deviceName)",
                                  symbol: "laptopcomputer", keywords: [url.host() ?? "", "other mac"]) { m, w in
                    _ = m.tabs.open(url: url, in: w, placement: .newTab)
                })
            }
        }
        for easel in EaselStore.shared.easels {
            list.append(.init(id: "easel.\(easel.id)", title: "Open Easel “\(easel.name.isEmpty ? "Untitled Easel" : easel.name)”", symbol: "scribble") { _, _ in
                EaselManager.shared.open(easel.id)
            })
        }
        return list
    }

    /// Commands for what was typed: ">" alone lists them all, ">word" or plain words narrow them.
    static func matching(_ typed: String, in m: BrowserManager, hasPage: Bool) -> [PaletteCommand] {
        var query = typed.trimmingCharacters(in: .whitespaces)
        let explicit = query.hasPrefix(">")
        if explicit { query = String(query.dropFirst()).trimmingCharacters(in: .whitespaces) }
        let words = query.split(separator: " ")
        guard explicit || (words.first?.count ?? 0) >= 2 else { return [] }
        return all(m).filter { (!$0.needsPage || hasPage) && (words.isEmpty || $0.matches(words)) }
    }

    static func run(_ id: String, in m: BrowserManager, window: BrowserWindowState) {
        all(m).first { $0.id == id }?.run(m, window)
    }

    static func symbol(for id: String, in m: BrowserManager) -> String {
        all(m).first { $0.id == id }?.symbol ?? "command"
    }
}
