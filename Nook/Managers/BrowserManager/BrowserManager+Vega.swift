// Licensed under GPL-3.0. See LICENSE.
//
//  BrowserManager+Vega.swift
//  Nook
//
//  FORK: menu entry points into Ask Vega.
//

import SwiftUI
import NookDesign

extension BrowserManager {
    /// Opens the chat panel on the active window and, for a task that needs no more input, sends it.
    func askVega(_ prompt: String?, task: AIService.ChatTask) {
        guard let window = windowRegistry?.activeWindow, let ai = aiService else { return }
        withAnimation(NookDesign.Motion.standard) { window.isSidebarAIChatVisible = true }
        if let prompt {
            Task { await ai.sendMessage(prompt, windowState: window, task: task) }
        } else {
            ai.pendingTask = task
        }
    }
}

// MARK: - Sharing a space

import AppKit
import UniformTypeIdentifiers
import NookWeb

extension UTType {
    /// A space saved to a file (`.vegaspace`).
    static let vegaSpace = UTType(exportedAs: "com.vega.browser.space", conformingTo: .json)
}

extension BrowserManager {
    private func spaceFileData(for spaceID: UUID) -> (name: String, data: Data)? {
        guard let shared = tabs.sharedSpace(spaceID) else { return nil }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(shared) else { return nil }
        let safe = shared.name.replacingOccurrences(of: "/", with: "-")
        return (safe.isEmpty ? "Space" : safe, data)
    }

    /// The system share sheet (AirDrop, Messages, Mail) with the space as a file.
    func shareSpace() {
        guard let window = windowRegistry?.activeWindow, let spaceID = window.spaceID, let file = spaceFileData(for: spaceID),
              let view = (window.window as? NSWindow)?.contentView else { return }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(file.name).vegaspace")
        do { try file.data.write(to: url, options: .atomic) } catch { return Self.saveFailed("Couldn't share the space", error) }
        let picker = NSSharingServicePicker(items: [url])
        picker.show(relativeTo: NSRect(x: view.bounds.midX - 1, y: view.bounds.maxY - 40, width: 2, height: 2), of: view, preferredEdge: .minY)
    }

    /// Saves the space where the person picks.
    func exportSpace() {
        guard let window = windowRegistry?.activeWindow, let spaceID = window.spaceID, let file = spaceFileData(for: spaceID) else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.vegaSpace]
        panel.nameFieldStringValue = "\(file.name).vegaspace"
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            do { try file.data.write(to: url, options: .atomic) } catch { Self.saveFailed("Couldn't export the space", error) }
        }
    }

    static func saveFailed(_ title: String, _ error: Error?) {
        let detail = error?.localizedDescription ?? "Check the folder and the free space on this Mac."
        SystemAlert.present(SystemAlert.make(title, detail, style: .warning, buttons: ["OK"])) { _ in }
    }

    /// Picks a `.vegaspace` file and opens it.
    func openSharedSpacePanel() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.vegaSpace]
        panel.allowsMultipleSelection = false
        panel.message = "Choose a space someone shared with you"
        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            self?.openSharedSpace(at: url)
        }
    }

    /// Asks before adding: a file from someone else brings a list of links.
    func openSharedSpace(at url: URL) {
        // Size first: a huge file is refused before it is read into memory.
        let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        guard size > 0, size < 4_000_000, let data = try? Data(contentsOf: url), let shared = TabsController.decodeSharedSpace(data) else {
            let alert = NSAlert()
            alert.messageText = "That isn't a Vega space"
            alert.informativeText = "The file couldn't be read, or it was made by a newer version of Vega."
            alert.runModal()
            return
        }
        let alert = NSAlert()
        alert.messageText = "Add the space “\(shared.name)”?"
        alert.informativeText = "It has \(shared.tabCount) \(shared.tabCount == 1 ? "page" : "pages"). Nothing is opened until you click it, and no logins come with it."
        alert.addButton(withTitle: "Add Space")
        alert.addButton(withTitle: "Cancel")
        // The space is added, not switched to: switching selects a tab and loads its page, and a file from
        // someone else must not open a link before you have looked at the list.
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        _ = tabs.importSharedSpace(shared)
    }
}

// MARK: - Clear data on quit

import WebKit
import NookSettings

extension BrowserManager {
    /// Every space's cookies, site data and cache, the default store's, and the history.
    func clearWebsiteDataAtQuit() async {
        let stores: [WKWebsiteDataStore] = tabs.orderedSpaces.compactMap { tabs.profile(forSpace: $0.id)?.dataStore } + [WKWebsiteDataStore.default()]
        let types = WKWebsiteDataStore.allWebsiteDataTypes()
        let kept = nookSettings?.keepSignedInSites ?? []
        for store in stores {
            if kept.isEmpty {
                await store.removeData(ofTypes: types, modifiedSince: .distantPast)
            } else {
                // FORK: sites the person keeps signed in keep their cookies and data; every other site's go.
                let records = await store.dataRecords(ofTypes: types)
                let cleared = records.filter { !KeepSignedIn.keeps($0.displayName, sites: kept) }
                await store.removeData(ofTypes: types, for: cleared)
            }
        }
        historyManager.clearHistory()
    }
}
