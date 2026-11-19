// Licensed under GPL-3.0. See LICENSE.
//
//  VegaPanels.swift
//  Nook
//
//  FORK: small utility windows (Task Manager, Privacy Report, Feature Tour), one of each, reopened in front.
//

import AppKit
import SwiftUI

@MainActor
final class VegaPanels {
    static let shared = VegaPanels()
    private var windows: [String: NSWindow] = [:]

    func show<Content: View>(_ id: String, title: String, size: CGSize, resizable: Bool = true, @ViewBuilder content: () -> Content) {
        if let window = windows[id] {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        var style: NSWindow.StyleMask = [.titled, .closable, .miniaturizable]
        if resizable { style.insert(.resizable) }
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: style, backing: .buffered, defer: false)
        window.contentViewController = NSHostingController(rootView: content())
        window.title = title
        // The hosting controller sizes the window to the view's minimum; open at the intended size instead.
        window.setContentSize(size)
        window.isReleasedWhenClosed = false
        window.setFrameAutosaveName("VegaPanel3-\(id)")
        if !window.setFrameUsingName("VegaPanel3-\(id)") { window.center() }
        windows[id] = window
        NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: window, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.windows[id] = nil }
        }
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func close(_ id: String) { windows[id]?.close() }
}

extension BrowserManager {
    func showTaskManager() {
        VegaPanels.shared.show("taskManager", title: "Task Manager", size: CGSize(width: 640, height: 520)) {
            TaskManagerView().environmentObject(self)
        }
    }

    func showPrivacyReport() {
        VegaPanels.shared.show("privacyReport", title: "Privacy Report", size: CGSize(width: 640, height: 860)) {
            PrivacyReportView().environmentObject(self)
        }
    }

    func showFeatureTour() {
        VegaPanels.shared.show("featureTour", title: "Welcome to Vega", size: CGSize(width: 620, height: 520), resizable: false) {
            FeatureTourView().environmentObject(self)
        }
    }
}
