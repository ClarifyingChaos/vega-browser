// What Import from Chrome reads: profiles, web bookmarks only, and recent history from a copy of the database.
// swiftc -parse-as-library Nook/Managers/ImportManager/Chrome.swift scripts/tests/ChromeImportCheck.swift -lsqlite3 -o /tmp/chromecheck && /tmp/chromecheck

import Foundation
import SQLite3

@main
struct ChromeImportCheck {
    static func main() throws {
        let files = FileManager.default
        let root = files.temporaryDirectory.appendingPathComponent("chrome-check-\(UUID().uuidString)")
        defer { try? files.removeItem(at: root) }
        for folder in ["Default", "Profile 1"] {
            try files.createDirectory(at: root.appendingPathComponent(folder), withIntermediateDirectories: true)
        }
        try Data(#"{"profile":{"info_cache":{"Profile 1":{"name":"Work"},"Default":{"name":"Person 1"},"Gone":{"name":"x"},"..":{"name":"y"}}}}"#.utf8)
            .write(to: root.appendingPathComponent("Local State"))
        precondition(readChromeProfiles(in: root).map(\.name) == ["Person 1", "Work"])
        precondition(readChromeProfiles(in: root.appendingPathComponent("missing")).isEmpty)

        func found(_ lookup: ChromeLookup) -> [String] { if case .found(let p) = lookup { p.map(\.id) } else { [] } }
        let support = root.appendingPathComponent("support"), data = support.appendingPathComponent("Google/Chrome")
        precondition(findChromeProfiles(support: support) == .notFound)
        for folder in ["Default", "Profile 2", "Profile 10", "Crashpad"] {
            try files.createDirectory(at: data.appendingPathComponent(folder), withIntermediateDirectories: true)
        }
        precondition(findChromeProfiles(support: support) == .notFound, "empty folders are not profiles")
        for folder in ["Default", "Profile 2", "Profile 10", "Crashpad"] {
            try Data("{}".utf8).write(to: data.appendingPathComponent("\(folder)/Bookmarks"))
        }
        // No list, a damaged one, and one that names nothing that is there.
        let state = data.appendingPathComponent("Local State")
        for text in [nil, "not json", #"{"profile":{"info_cache":{"Gone":{"name":"x"}}}}"#] as [String?] {
            try? files.removeItem(at: state)
            if let text { try Data(text.utf8).write(to: state) }
            precondition(found(findChromeProfiles(support: support)) == ["Default", "Profile 2", "Profile 10"], "\(text ?? "no list")")
        }
        // The folder the person picks: the one around Chrome's, or a profile's own.
        precondition(found(findChromeProfiles(in: support.appendingPathComponent("Google"))).count == 3)
        precondition(found(findChromeProfiles(in: data.appendingPathComponent("Profile 2"))) == ["Profile 2"])
        // Another channel is found when it is the only one.
        let beta = root.appendingPathComponent("beta/Google/Chrome Beta/Default")
        try files.createDirectory(at: beta, withIntermediateDirectories: true)
        try Data("{}".utf8).write(to: beta.appendingPathComponent("History"))
        precondition(found(findChromeProfiles(support: root.appendingPathComponent("beta"))) == ["Default"])
        // Refused is said as refused, not as nothing there.
        try files.setAttributes([.posixPermissions: 0], ofItemAtPath: data.path)
        defer { try? files.setAttributes([.posixPermissions: 0o700], ofItemAtPath: data.path) }
        precondition(findChromeProfiles(support: support) == .unreadable)
        precondition(findChromeProfiles(in: data) == .unreadable)

        let bookmarks = parseChromeBookmarks(Data(#"""
        {"roots":{"bookmark_bar":{"children":[
            {"type":"url","name":"A","url":"https://a.test/"},
            {"type":"url","name":"bad","url":"javascript:alert(1)"},
            {"type":"url","name":"page","url":"chrome://settings"},
            {"type":"folder","name":"F","children":[{"type":"url","name":"","url":"http://b.test/"}]},
            {"type":"folder","name":"Empty","children":[{"type":"url","name":"f","url":"file:///etc/passwd"}]}]},
          "other":{"children":[{"type":"url","name":"C","url":"https://c.test/"}]},
          "synced":{"children":[]}}}
        """#.utf8))
        precondition(bookmarks == [
            .bookmark(url: "https://a.test/", title: "A"),
            .folder(title: "F", children: [.bookmark(url: "http://b.test/", title: "")]),
            .folder(title: "Other Bookmarks", children: [.bookmark(url: "https://c.test/", title: "C")]),
        ], "\(bookmarks)")
        precondition(chromeBookmarkCount(bookmarks) == (3, 2))
        precondition(parseChromeBookmarks(Data("not json".utf8)).isEmpty)

        let profile = root.appendingPathComponent("Default")
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        func stamp(_ daysAgo: Double) -> Int64 { Int64((now.timeIntervalSince1970 - daysAgo * 86_400 + 11_644_473_600) * 1_000_000) }
        var database: OpaquePointer?
        precondition(sqlite3_open(profile.appendingPathComponent("History").path, &database) == SQLITE_OK)
        precondition(sqlite3_exec(database, """
        CREATE TABLE urls(url TEXT, title TEXT, last_visit_time INTEGER, hidden INTEGER);
        INSERT INTO urls VALUES('https://new.test/', 'New', \(stamp(1)), 0), ('https://old.test/', 'Old', \(stamp(200)), 0),
          ('https://hidden.test/', 'H', \(stamp(1)), 1), ('chrome://history', 'C', \(stamp(1)), 0), ('https://week.test/', NULL, \(stamp(7)), 0);
        """, nil, nil, nil) == SQLITE_OK)
        // Chrome holds the database while it runs.
        precondition(sqlite3_exec(database, "BEGIN EXCLUSIVE", nil, nil, nil) == SQLITE_OK)
        let visits = chromeHistory(profile: profile, now: now)!
        precondition(visits.map(\.url.absoluteString) == ["https://new.test/", "https://week.test/"], "\(visits)")
        precondition(visits[0].title == "New" && abs(visits[0].date.timeIntervalSince(now) + 86_400) < 1)
        precondition(chromeHistory(profile: profile, limit: 1, now: now)!.count == 1)
        precondition(chromeHistory(profile: root.appendingPathComponent("Profile 1"), now: now) == nil, "no database is a failure, not zero pages")
        sqlite3_close(database)
        print("ChromeImportCheck passed")
    }
}
