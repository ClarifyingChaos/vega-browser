// Licensed under GPL-3.0. See LICENSE.
//
//  CaptureLibrary.swift
//  Nook
//
//  FORK: Arc's captures. Every Capture Visible Area / Capture Full Page is kept in Vega's own folder and shows in the
//  Library's Media view, wherever the person also saves a copy, so the Library always lists all of them.
//

import AppKit
import Foundation

@MainActor
@Observable
final class CaptureLibrary {
    static let shared = CaptureLibrary()

    /// Newest first. Each is a finished `Download` standing for the file, so the Media grid and the in-window preview
    /// treat it like any other image.
    private(set) var items: [Download] = []
    /// The capture just taken, for the toast that offers to open or save it.
    private(set) var latest: Download?

    /// The screenshots and screen recordings taken with macOS itself, newest first, from wherever they were saved.
    private(set) var systemShots: [Download] = []

    @ObservationIgnored private var loaded = false
    @ObservationIgnored private var shotCache: [String: Download] = [:]
    @ObservationIgnored private var query: NSMetadataQuery?
    @ObservationIgnored private var scanning = false

    static var folder: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory())
        return base.appendingPathComponent(Bundle.main.bundleIdentifier ?? "Vega", isDirectory: true)
            .appendingPathComponent("Captures", isDirectory: true)
    }

    /// Reads the folder the first time the list is wanted; the files are small, the check is quick.
    func loadIfNeeded() {
        guard !loaded else { return }
        loaded = true
        let files = (try? FileManager.default.contentsOfDirectory(
            at: Self.folder, includingPropertiesForKeys: [.creationDateKey, .fileSizeKey], options: [.skipsHiddenFiles])) ?? []
        items = files.filter { $0.pathExtension.lowercased() == "png" }.map(Self.wrap).sorted { $0.startDate > $1.startDate }
    }

    /// Writes the PNG into the folder, puts the picture on the clipboard, and lists it.
    @discardableResult
    func save(png: Data, image: NSImage, host: String, fullPage: Bool) throws -> Download {
        loadIfNeeded()
        try FileManager.default.createDirectory(at: Self.folder, withIntermediateDirectories: true)
        let stamp = Self.stamp.string(from: Date())
        let name = "\(host.isEmpty ? "Page" : host) \(fullPage ? "full page" : "capture") \(stamp).png"
        let url = Self.folder.appendingPathComponent(name)
        try png.write(to: url, options: .atomic)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.writeObjects([image])
        let item = Self.wrap(url)
        items.insert(item, at: 0)
        latest = item
        return item
    }

    func dismissLatest() { latest = nil }

    // MARK: - Screenshots taken with macOS

    private static let mediaExtensions: Set<String> = ["png", "jpg", "jpeg", "heic", "tiff", "gif", "mov", "mp4"]

    /// Where macOS saves screenshots: the folder set in Screenshot options (shown by `defaults read com.apple.screencapture
    /// location`), else the Desktop.
    static var screenshotFolder: URL {
        if let path = UserDefaults(suiteName: "com.apple.screencapture")?.string(forKey: "location"), !path.isEmpty {
            return URL(fileURLWithPath: (path as NSString).expandingTildeInPath, isDirectory: true)
        }
        return FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop", isDirectory: true)
    }

    /// A screenshot, by macOS's own mark on the file (it sets this whatever the file is called or where it goes) or by
    /// the names it gives them.
    private nonisolated static func isScreenshot(_ url: URL) -> Bool {
        guard mediaExtensions.contains(url.pathExtension.lowercased()) else { return false }
        let name = url.lastPathComponent
        if name.hasPrefix("Screenshot") || name.hasPrefix("Screen Shot") || name.hasPrefix("Screen Recording") { return true }
        return getxattr(url.path, "com.apple.metadata:kMDItemIsScreenCapture", nil, 0, 0, XATTR_NOFOLLOW) > 0
    }

    /// Reads the screenshot folder and the Desktop directly, so a folder Spotlight doesn't index (an external drive) is
    /// listed too, then adds what Spotlight itself has marked as a screenshot anywhere else.
    func refreshSystemShots() {
        startSpotlightQuery()
        guard !scanning else { return }
        scanning = true
        let folders = [Self.screenshotFolder, FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop", isDirectory: true)]
        let spotlight = spotlightPaths()
        let ownFolder = Self.folder.path
        Task.detached(priority: .utility) {
            var seen = Set<String>()
            var found: [(url: URL, date: Date, size: Int64?)] = []
            func add(_ url: URL) {
                guard seen.insert(url.path).inserted, Self.isScreenshot(url),
                      !url.path.contains("/.Trash/"), !url.path.hasPrefix(ownFolder) else { return }
                let values = try? url.resourceValues(forKeys: [.creationDateKey, .fileSizeKey])
                found.append((url, values?.creationDate ?? .distantPast, values?.fileSize.map(Int64.init)))
            }
            for folder in folders {
                let files = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])) ?? []
                files.forEach(add)
            }
            spotlight.map { URL(fileURLWithPath: $0) }.forEach(add)
            let sorted = found.sorted { $0.date > $1.date }.prefix(400)
            await MainActor.run { CaptureLibrary.shared.apply(Array(sorted)) }
        }
    }

    private func apply(_ files: [(url: URL, date: Date, size: Int64?)]) {
        scanning = false
        var next: [Download] = []
        for file in files {
            let item = shotCache[file.url.path] ?? Self.wrap(file.url)
            item.startDate = file.date == .distantPast ? item.startDate : file.date
            shotCache[file.url.path] = item
            next.append(item)
        }
        // Drop what has gone from disk or from the list, so a deleted screenshot leaves the grid.
        let live = Set(next.map(\.id))
        shotCache = shotCache.filter { live.contains($0.value.id) }
        if systemShots.map(\.id) != next.map(\.id) { systemShots = next }
    }

    private func startSpotlightQuery() {
        guard query == nil else { return }
        let query = NSMetadataQuery()
        query.predicate = NSPredicate(format: "kMDItemIsScreenCapture == 1")
        query.searchScopes = [NSMetadataQueryLocalComputerScope]
        query.notificationBatchingInterval = 2
        for name in [NSNotification.Name.NSMetadataQueryDidFinishGathering, .NSMetadataQueryDidUpdate] {
            NotificationCenter.default.addObserver(forName: name, object: query, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.scanning = false; self?.refreshSystemShots() }
            }
        }
        self.query = query
        query.start()
    }

    private func spotlightPaths() -> [String] {
        guard let query else { return [] }
        query.disableUpdates()
        defer { query.enableUpdates() }
        return (0 ..< min(query.resultCount, 400)).compactMap { (query.result(at: $0) as? NSMetadataItem)?.value(forAttribute: NSMetadataItemPathKey) as? String }
    }

    /// Moves a system screenshot to the Trash, as Finder would, and drops it from the list.
    func trash(_ item: Download) {
        if let url = item.destinationURL { try? FileManager.default.trashItem(at: url, resultingItemURL: nil) }
        refreshSystemShots()
    }

    /// Moves the file to the Trash and takes it off the list.
    func delete(_ item: Download) {
        if let url = item.destinationURL { try? FileManager.default.trashItem(at: url, resultingItemURL: nil) }
        items.removeAll { $0.id == item.id }
        if latest?.id == item.id { latest = nil }
    }

    private static func wrap(_ url: URL) -> Download {
        let item = Download(download: nil, originalURL: url, suggestedFilename: url.lastPathComponent,
                            origin: DownloadOrigin(isPrivate: false, profileID: nil, pageTitle: nil), state: .completed)
        item.destinationURL = url
        let values = try? url.resourceValues(forKeys: [.creationDateKey, .fileSizeKey])
        item.startDate = values?.creationDate ?? Date()
        item.fileSize = values?.fileSize.map(Int64.init)
        return item
    }

    private static let stamp: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd 'at' HH.mm.ss"
        return formatter
    }()
}
