// Licensed under GPL-3.0. See LICENSE.
//
//  CrashReporter.swift
//  Vega
//
//  FORK: opt-in crash reports. When the last session ended in a crash (macOS wrote a Vega report to
//  ~/Library/Logs/DiagnosticReports), Vega offers to open a GitHub issue with a short summary: version, macOS, the
//  kind of crash and the crashed thread's functions, home folder paths shortened to ~. Nothing is sent by itself: the
//  person reads the issue in their browser and submits it, or not.
//

import AppKit
import Foundation

@MainActor
enum CrashReporter {
    static let optInKey = "fork.crashReports.offer"
    private static var markerURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(Bundle.main.bundleIdentifier ?? "com.vega.browser", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base.appendingPathComponent("session-running")
    }
    private static let issuesURL = "https://github.com/ClarifyingChaos/vega-browser/issues/new"

    /// At launch: was the last session cut short by a crash? Then marks this session as running.
    static func launch() {
        let fm = FileManager.default
        let previous = (try? fm.attributesOfItem(atPath: markerURL.path))?[.modificationDate] as? Date
        try? Data().write(to: markerURL)
        guard let previous, UserDefaults.standard.bool(forKey: optInKey), let report = newestReport(since: previous) else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { offer(report) }
    }

    /// At a normal quit.
    static func cleanExit() { try? FileManager.default.removeItem(at: markerURL) }

    static func newestReport(since date: Date) -> URL? {
        let dir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Logs/DiagnosticReports")
        let names = (try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.contentModificationDateKey])) ?? []
        return names
            .filter { $0.lastPathComponent.hasPrefix("Vega") && ["ips", "crash"].contains($0.pathExtension) }
            .compactMap { url -> (URL, Date)? in
                guard let d = try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate, d >= date else { return nil }
                return (url, d)
            }
            .max { $0.1 < $1.1 }?.0
    }

    private static func offer(_ report: URL) {
        let alert = NSAlert()
        alert.messageText = "Vega quit unexpectedly last time"
        alert.informativeText = "You can send a short report so it gets fixed. It holds Vega's version, your macOS version and where Vega crashed: no pages, passwords or history. You'll see it in your browser before anything is sent."
        alert.addButton(withTitle: "Review Report…")
        alert.addButton(withTitle: "Not Now")
        alert.addButton(withTitle: "Show in Finder")
        switch alert.runModal() {
        case .alertFirstButtonReturn:
            if let url = issueURL(for: report) { NSWorkspace.shared.open(url) }
        case .alertThirdButtonReturn:
            NSWorkspace.shared.activateFileViewerSelecting([report])
        default: break
        }
    }

    static func issueURL(for report: URL) -> URL? {
        guard let text = try? String(contentsOf: report, encoding: .utf8) else { return nil }
        let summary = summarize(text)
        var parts = URLComponents(string: issuesURL)
        parts?.queryItems = [.init(name: "title", value: "Crash: \(summary.title)"), .init(name: "body", value: summary.body)]
        return parts?.url
    }

    /// The version, the crash and the crashed thread, from an .ips report (JSON after a one-line header).
    static func summarize(_ text: String) -> (title: String, body: String) {
        let home = NSHomeDirectory()
        let info = Bundle.main.infoDictionary
        let version = "\(info?["CFBundleShortVersionString"] as? String ?? "?") (\(info?["CFBundleVersion"] as? String ?? "?"))"
        let os = ProcessInfo.processInfo.operatingSystemVersionString
        var kind = "unknown", frames: [String] = []
        let lines = text.split(separator: "\n", maxSplits: 1).map(String.init)
        if lines.count == 2, let data = lines[1].data(using: .utf8), let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let exception = json["exception"] as? [String: Any] {
                kind = [exception["type"] as? String, exception["signal"] as? String].compactMap { $0 }.joined(separator: " / ")
            }
            let images = (json["usedImages"] as? [[String: Any]])?.map { ($0["name"] as? String) ?? "?" } ?? []
            if let threads = json["threads"] as? [[String: Any]], let crashed = threads.first(where: { $0["triggered"] as? Bool == true }),
               let list = crashed["frames"] as? [[String: Any]] {
                frames = list.prefix(15).map { frame in
                    let image = (frame["imageIndex"] as? Int).flatMap { $0 < images.count ? images[$0] : nil } ?? "?"
                    return "\(image)  \(frame["symbol"] as? String ?? "?")"
                }
            }
        }
        let body = """
        **Vega** \(version) on \(os)
        **Crash:** \(kind)

        Crashed thread:
        ```
        \(frames.isEmpty ? "(not in the report)" : frames.joined(separator: "\n"))
        ```

        What I was doing when it happened:

        """
        return (kind, body.replacingOccurrences(of: home, with: "~"))
    }
}
