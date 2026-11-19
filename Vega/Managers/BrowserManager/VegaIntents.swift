// Licensed under GPL-3.0. See LICENSE.
//
//  VegaIntents.swift
//  Vega
//
//  FORK: Shortcuts actions: open a page, search, switch space, start an easel, show the Task Manager. They run the
//  same commands as vega:// links, without that setting's gate (it protects against other apps; a shortcut is the
//  person's own).
//

import AppIntents
import AppKit
import Foundation

@MainActor
enum VegaIntents {
    static weak var browserManager: BrowserManager?

    static func run(_ action: String, _ items: [URLQueryItem]) throws {
        var parts = URLComponents()
        parts.scheme = "vega"
        parts.host = action
        parts.queryItems = items.filter { !($0.value ?? "").isEmpty }
        guard let link = parts.url, let manager = browserManager else { throw VegaIntentError.notReady }
        NSApp.activate(ignoringOtherApps: true)
        guard manager.runLauncherLink(link) else { throw VegaIntentError.failed }
    }
}

enum VegaIntentError: Error, CustomLocalizedStringResourceConvertible {
    case notReady, failed
    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .notReady: "Vega is still starting. Try again in a moment."
        case .failed: "Vega couldn't do that. Check the address or the space's name."
        }
    }
}

struct OpenPageInVegaIntent: AppIntent {
    static let title: LocalizedStringResource = "Open Page in Vega"
    static let description = IntentDescription("Opens a web page in Vega, in a space if you name one.")
    static let openAppWhenRun = true

    @Parameter(title: "Address") var url: URL
    @Parameter(title: "Space") var space: String?
    @Parameter(title: "Use an Open Tab", default: false) var reuse: Bool

    @MainActor func perform() async throws -> some IntentResult {
        try VegaIntents.run("open", [.init(name: "url", value: url.absoluteString), .init(name: "space", value: space),
                                     .init(name: "reuse", value: reuse ? "1" : nil)])
        return .result()
    }
}

struct SearchInVegaIntent: AppIntent {
    static let title: LocalizedStringResource = "Search in Vega"
    static let description = IntentDescription("Searches the web in Vega with your search engine.")
    static let openAppWhenRun = true

    @Parameter(title: "Search For") var query: String
    @Parameter(title: "Space") var space: String?

    @MainActor func perform() async throws -> some IntentResult {
        try VegaIntents.run("search", [.init(name: "q", value: query), .init(name: "space", value: space)])
        return .result()
    }
}

struct SwitchVegaSpaceIntent: AppIntent {
    static let title: LocalizedStringResource = "Switch Vega Space"
    static let description = IntentDescription("Shows a space in Vega's front window.")
    static let openAppWhenRun = true

    @Parameter(title: "Space") var space: String

    @MainActor func perform() async throws -> some IntentResult {
        try VegaIntents.run("space", [.init(name: "name", value: space)])
        return .result()
    }
}

struct NewVegaEaselIntent: AppIntent {
    static let title: LocalizedStringResource = "New Vega Easel"
    static let description = IntentDescription("Starts a new easel in Vega.")
    static let openAppWhenRun = true

    @MainActor func perform() async throws -> some IntentResult {
        NSApp.activate(ignoringOtherApps: true)
        EaselManager.shared.newEasel()
        return .result()
    }
}

struct ShowVegaTaskManagerIntent: AppIntent {
    static let title: LocalizedStringResource = "Show Vega Task Manager"
    static let description = IntentDescription("Shows what each tab uses, and puts tabs to sleep.")
    static let openAppWhenRun = true

    @MainActor func perform() async throws -> some IntentResult {
        guard let manager = VegaIntents.browserManager else { throw VegaIntentError.notReady }
        NSApp.activate(ignoringOtherApps: true)
        manager.showTaskManager()
        return .result()
    }
}

struct VegaShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: OpenPageInVegaIntent(), phrases: ["Open a page in \(.applicationName)"], shortTitle: "Open Page", systemImageName: "safari")
        AppShortcut(intent: SearchInVegaIntent(), phrases: ["Search in \(.applicationName)"], shortTitle: "Search", systemImageName: "magnifyingglass")
        AppShortcut(intent: SwitchVegaSpaceIntent(), phrases: ["Switch \(.applicationName) space"], shortTitle: "Switch Space", systemImageName: "square.on.square")
        AppShortcut(intent: NewVegaEaselIntent(), phrases: ["New \(.applicationName) easel"], shortTitle: "New Easel", systemImageName: "scribble.variable")
        AppShortcut(intent: ShowVegaTaskManagerIntent(), phrases: ["Show \(.applicationName) Task Manager"], shortTitle: "Task Manager", systemImageName: "gauge.with.dots.needle.33percent")
    }
}
