// Licensed under GPL-3.0. See LICENSE.
//
//  Chrome.swift
//  Nook
//
//  FORK: reads what Import from Chrome brings over: profile names, bookmarks and recent history.
//  Cookies, saved passwords and cards are never opened.
//

import Foundation
import SQLite3

struct ChromeProfile: Identifiable, Equatable {
    /// The folder inside Chrome's data directory: "Default", "Profile 1".
    let id: String
    let name: String
    let directory: URL
}

indirect enum ChromeNode: Equatable {
    case bookmark(url: String, title: String)
    case folder(title: String, children: [ChromeNode])
}

struct ChromeVisit: Equatable {
    let url: URL
    let title: String
    let date: Date
}

/// The profiles `Local State` names whose folder is there, "Default" first.
func readChromeProfiles(in userData: URL) -> [ChromeProfile] {
    let state = (try? Data(contentsOf: userData.appendingPathComponent("Local State")))
        .flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }
    let cache = (state?["profile"] as? [String: Any])?["info_cache"] as? [String: Any] ?? [:]
    return cache.compactMap { folder, info -> ChromeProfile? in
        // A folder name is one path component: nothing in the file may point elsewhere.
        guard !folder.contains("/"), folder != "..", folder != "." else { return nil }
        let directory = userData.appendingPathComponent(folder)
        guard FileManager.default.fileExists(atPath: directory.path) else { return nil }
        let name = (info as? [String: Any])?["name"] as? String
        return ChromeProfile(id: folder, name: name?.isEmpty == false ? name! : folder, directory: directory)
    }
    .sorted { $0.id == "Default" || ($1.id != "Default" && $0.id.localizedStandardCompare($1.id) == .orderedAscending) }
}

/// What looking for Chrome's data came to.
enum ChromeLookup: Equatable {
    case found([ChromeProfile])
    /// The data is there but macOS or the file's permissions refuse it.
    case unreadable
    case notFound
}

/// Where Chrome and its other channels keep their data, inside Application Support.
let chromeDataFolders = ["Google/Chrome", "Google/Chrome Beta", "Google/Chrome Dev", "Google/Chrome Canary", "Chromium"]

/// The first of Chrome's usual folders in `support` that holds a readable profile.
func findChromeProfiles(support: URL) -> ChromeLookup {
    var result = ChromeLookup.notFound
    for folder in chromeDataFolders {
        switch findChromeProfiles(in: support.appendingPathComponent(folder)) {
        case .found(let profiles): return .found(profiles)
        case .unreadable: result = .unreadable
        case .notFound: break
        }
    }
    return result
}

/// The profiles in `folder`: Chrome's data folder, the "Google" folder around it, or one profile's own folder. When
/// Chrome's list of profiles is missing or damaged, the folders named as Chrome names profiles are taken instead.
func findChromeProfiles(in folder: URL) -> ChromeLookup {
    let files = FileManager.default
    var refused = false
    func attempt<T>(_ read: () throws -> T) -> T? {
        do { return try read() } catch {
            if (error as? CocoaError)?.code == .fileReadNoPermission { refused = true }
            return nil
        }
    }
    func names(_ url: URL) -> [String]? { attempt { try files.contentsOfDirectory(atPath: url.path) } }
    func holdsData(_ names: [String]?) -> Bool { names?.contains { ["Bookmarks", "History"].contains($0) } == true }

    for data in [folder, folder.appendingPathComponent("Chrome")] {
        _ = attempt { try Data(contentsOf: data.appendingPathComponent("Local State")) }
        let listed = readChromeProfiles(in: data).filter { names($0.directory) != nil }
        if !listed.isEmpty { return .found(listed) }
        let scanned = (names(data) ?? []).filter { $0 == "Default" || $0.hasPrefix("Profile ") }
            .sorted { $0 == "Default" || ($1 != "Default" && $0.localizedStandardCompare($1) == .orderedAscending) }
            .compactMap { name -> ChromeProfile? in
                let directory = data.appendingPathComponent(name)
                return holdsData(names(directory)) ? ChromeProfile(id: name, name: name, directory: directory) : nil
            }
        if !scanned.isEmpty { return .found(scanned) }
    }
    if holdsData(names(folder)) {
        let name = folder.lastPathComponent
        return .found([ChromeProfile(id: name, name: name, directory: folder)])
    }
    return refused ? .unreadable : .notFound
}

/// The `Bookmarks` file as a tree: the bookmarks bar's entries first, then the other two roots as
/// folders. Only web addresses come over, so a `javascript:` bookmarklet or a Chrome page stays behind.
func parseChromeBookmarks(_ data: Data) -> [ChromeNode] {
    guard let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
          let roots = root["roots"] as? [String: Any] else { return [] }

    func children(_ node: Any?, depth: Int) -> [ChromeNode] {
        guard depth < 32, let list = (node as? [String: Any])?["children"] as? [[String: Any]] else { return [] }
        return list.compactMap { entry in
            let title = entry["name"] as? String ?? ""
            if entry["type"] as? String == "folder" {
                let inside = children(entry, depth: depth + 1)
                return inside.isEmpty ? nil : .folder(title: title.isEmpty ? "Folder" : title, children: inside)
            }
            guard let url = entry["url"] as? String,
                  ["http", "https"].contains(URL(string: url)?.scheme?.lowercased()) else { return nil }
            return .bookmark(url: url, title: title)
        }
    }

    var tree = children(roots["bookmark_bar"], depth: 0)
    for (key, title) in [("other", "Other Bookmarks"), ("synced", "Mobile Bookmarks")] {
        let inside = children(roots[key], depth: 0)
        if !inside.isEmpty { tree.append(.folder(title: title, children: inside)) }
    }
    return tree
}

func chromeBookmarkCount(_ nodes: [ChromeNode]) -> (bookmarks: Int, folders: Int) {
    nodes.reduce((0, 0)) { total, node in
        switch node {
        case .bookmark: return (total.0 + 1, total.1)
        case .folder(_, let children):
            let inside = chromeBookmarkCount(children)
            return (total.0 + inside.bookmarks, total.1 + 1 + inside.folders)
        }
    }
}

/// Pages visited in the last `days` days, newest first, one row per address. Chrome may hold its
/// database open, so a copy is read and then deleted.
func chromeHistory(profile: URL, days: Int = 90, limit: Int = 20_000, now: Date = Date()) -> [ChromeVisit]? {
    let files = FileManager.default
    let folder = files.temporaryDirectory.appendingPathComponent("chrome-history-\(UUID().uuidString)")
    guard (try? files.createDirectory(at: folder, withIntermediateDirectories: true,
                                      attributes: [.posixPermissions: 0o700])) != nil else { return nil }
    defer { try? files.removeItem(at: folder) }
    let copy = folder.appendingPathComponent("History")
    guard (try? files.copyItem(at: profile.appendingPathComponent("History"), to: copy)) != nil else { return nil }
    // A change Chrome had not finished is rolled back from its journal.
    try? files.copyItem(at: profile.appendingPathComponent("History-journal"),
                        to: folder.appendingPathComponent("History-journal"))

    var database: OpaquePointer?
    defer { sqlite3_close(database) }
    guard sqlite3_open_v2(copy.path, &database, SQLITE_OPEN_READWRITE, nil) == SQLITE_OK else { return nil }
    var statement: OpaquePointer?
    defer { sqlite3_finalize(statement) }
    let sql = "SELECT url, title, last_visit_time FROM urls WHERE hidden = 0 AND last_visit_time >= ?1 ORDER BY last_visit_time DESC LIMIT ?2"
    guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else { return nil }

    // Chrome counts microseconds from 1601.
    let epoch = 11_644_473_600.0
    let cutoff = now.addingTimeInterval(-Double(days) * 86_400).timeIntervalSince1970
    sqlite3_bind_int64(statement, 1, Int64((cutoff + epoch) * 1_000_000))
    sqlite3_bind_int(statement, 2, Int32(limit))

    var visits: [ChromeVisit] = []
    var step = sqlite3_step(statement)
    while step == SQLITE_ROW {
        if let text = sqlite3_column_text(statement, 0), let url = URL(string: String(cString: text)),
           ["http", "https"].contains(url.scheme?.lowercased()) {
            let title = sqlite3_column_text(statement, 1).map { String(cString: $0) } ?? ""
            let seconds = Double(sqlite3_column_int64(statement, 2)) / 1_000_000 - epoch
            visits.append(ChromeVisit(url: url, title: title, date: Date(timeIntervalSince1970: seconds)))
        }
        step = sqlite3_step(statement)
    }
    return step == SQLITE_DONE ? visits : nil
}
