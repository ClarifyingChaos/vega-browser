// Licensed under GPL-3.0. See LICENSE.
//
//  EaselManager.swift
//  Nook
//
//  FORK: opens each easel in its own window and adds the page in front to one.
//

import AppKit
import SwiftUI

@MainActor
final class EaselManager {
    static let shared = EaselManager()
    private var windows: [UUID: NSWindow] = [:]
    weak var browserManager: BrowserManager?

    func newEasel() {
        let easel = EaselStore.shared.create(named: "Untitled Easel")
        open(easel.id)
    }

    func open(_ id: UUID) {
        if let window = windows[id] { window.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true); return }
        guard let easel = EaselStore.shared.easel(id) else { return }
        let view = EaselView(easelID: id, currentPage: { [weak self] in self?.currentPage() },
                             openPage: { [weak self] url in self?.openPage(url) })
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 980, height: 680), styleMask: [.titled, .closable, .miniaturizable, .resizable],
                              backing: .buffered, defer: false)
        window.contentViewController = NSHostingController(rootView: view)
        window.title = easel.name
        window.isReleasedWhenClosed = false
        window.center()
        window.setFrameAutosaveName("Easel-\(id.uuidString)")
        windows[id] = window
        NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: window, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.windows[id] = nil; EaselStore.shared.flush() }
        }
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func delete(_ id: UUID) {
        windows[id]?.close()
        EaselStore.shared.delete(id)
    }

    func currentPage() -> (title: String, url: URL)? {
        guard let manager = browserManager, let session = manager.tabs.activeWindowSession,
              ["http", "https"].contains(session.url.scheme?.lowercased()) else { return nil }
        return (session.title.isEmpty ? (session.url.host() ?? "Page") : session.title, session.url)
    }

    /// Adds the page in front to an easel and shows the easel.
    func addCurrentPage(to id: UUID) {
        guard let page = currentPage() else { return }
        EaselStore.shared.mutate(id) { easel in
            let n = Double(easel.items.count)
            easel.items.append(EaselItem(kind: .link, x: 120 + n.truncatingRemainder(dividingBy: 8) * 28, y: 100 + n.truncatingRemainder(dividingBy: 8) * 28,
                                         w: 260, h: 84, text: page.title, url: page.url.absoluteString))
        }
        open(id)
    }

    private func openPage(_ url: URL) {
        guard let manager = browserManager, let window = manager.windowRegistry?.activeWindow else { return }
        _ = manager.tabs.open(url: url, in: window, placement: .newTab)
        if let main = (window.window as? NSWindow) { main.makeKeyAndOrderFront(nil) }
        NSApp.activate(ignoringOtherApps: true)
    }
}
