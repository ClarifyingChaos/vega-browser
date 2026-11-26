// Licensed under GPL-3.0. See LICENSE.
//
//  FaviconKeyCheck.swift
//  Nook
//
//  Favicon cache key check. Compiles the shipped source directly:
//
//    swiftc Packages/NookWeb/Sources/NookWeb/FaviconCache.swift \
//           Packages/NookWeb/Checks/FaviconKeyShim.swift \
//           Packages/NookWeb/Checks/FaviconKeyCheck.swift -o /tmp/favicon-key-check && /tmp/favicon-key-check
//

import AppKit
import Foundation

@main
struct FaviconKeyCheck {
    static func key(_ s: String) -> String? { FaviconCache.key(for: URL(string: s)!) }

    static func main() {
        precondition(key("http://h") == "h")
        precondition(key("http://h:80") == "h")
        precondition(key("https://h:443") == "h")
        precondition(key("https://h") == "h")
        precondition(key("http://h:8080") == "h_8080")
        precondition(key("https://h:8443") == "h_8443")
        precondition(key("http://h:443") == "h_443")
        precondition(key("http://[::1]:8080") == "::1_8080")
        precondition(key("mailto:a@b") == nil)

        for k in ["::1_8080", "a/b", "h_8080", "x.y-z"] {
            let name = FaviconCache.shared.fileName(k)
            precondition(name.range(of: "^[A-Za-z0-9._-]+$", options: .regularExpression) != nil, name)
        }
        precondition(FaviconCache.shared.fileName("::1_8080") == "__1_8080.png")
        precondition(FaviconCache.shared.fileName("example.com") == "example.com.png")
        // Background fetches go to public https hosts only.
        func pub(_ s: String) -> Bool { FaviconCache.isPublicHTTPS(URL(string: s)!) }
        precondition(pub("https://example.com/x"))
        precondition(!pub("http://example.com"), "plain http")
        precondition(!pub("https://localhost:3000"))
        precondition(!pub("https://192.168.1.1"), "IP address")
        precondition(!pub("https://[::1]"), "IPv6")
        precondition(!pub("https://printer.local"))
        precondition(!pub("https://intranet"), "no dot")

        // Reading counts as use: a read key outlives the keys stored after it.
        let cache = FaviconCache.shared
        let icon = NSImage(size: NSSize(width: 4, height: 4))
        cache.store(icon, for: "keep.example", toDisk: false)
        for i in 0..<(FaviconCache.maxMemoryEntries - 1) { cache.store(icon, for: "fill\(i).example", toDisk: false) }
        _ = cache.image(for: "keep.example")                        // used, so now the newest
        for i in 0..<30 { cache.store(icon, for: "later\(i).example", toDisk: false) }
        precondition(cache.image(for: "keep.example") != nil, "a read entry is kept")
        precondition(cache.image(for: "fill0.example") == nil, "the least recently used goes first")

        // One icon per page, as Chromium keeps them: the path counts, the query and fragment don't; the root is the site.
        func page(_ s: String) -> String? { FaviconCache.pageKey(for: URL(string: s)!) }
        precondition(page("https://docs.google.com/") == "docs.google.com")
        precondition(page("https://docs.google.com") == "docs.google.com")
        precondition(page("https://docs.google.com/spreadsheets/?a=1#x") == "docs.google.com/spreadsheets")
        precondition(page("https://h:8080/a/") == "h_8080/a")
        precondition(FaviconCache.lookupKeys(for: URL(string: "https://d.example/x")!) == ["d.example/x", "d.example"])
        precondition(FaviconCache.lookupKeys(for: URL(string: "https://d.example/")!) == ["d.example"])
        precondition(cache.fileName("a/b") != cache.fileName("a_b"), "a path never collides")
        precondition(cache.fileName("h/" + String(repeating: "p", count: 400)).count < 200, "long paths fit a file name")

        // Distinct pictures, so pngData (the shim's TIFF) tells them apart.
        func dot(_ color: NSColor) -> NSImage {
            let image = NSImage(size: NSSize(width: 4, height: 4))
            image.lockFocus(); color.setFill(); NSRect(x: 0, y: 0, width: 4, height: 4).fill(); image.unlockFocus()
            return image
        }
        func same(_ a: NSImage?, _ b: NSImage) -> Bool { a?.tiffRepresentation == b.tiffRepresentation }
        let sheets = dot(.green), docs = dot(.blue), meet = dot(.orange), google = dot(.red)
        func u(_ s: String) -> URL { URL(string: s)! }
        // The first page seen sets its site's icon and stands for it.
        precondition(cache.store(sheets, forPage: u("https://d.check/spreadsheets/1"), toDisk: false) == "d.check")
        precondition(cache.isSettled("d.check", for: u("https://d.check/spreadsheets/1")))
        // Another page with its own icon keeps it; the site's stays for the rest.
        precondition(cache.store(docs, forPage: u("https://d.check/document/2"), toDisk: false) == "d.check/document/2")
        precondition(same(cache.image(forPage: u("https://d.check/document/2")), docs))
        precondition(same(cache.image(forPage: u("https://d.check/spreadsheets/1")), sheets))
        // A page never seen borrows the site's icon but isn't settled, so it reads its own links when it loads.
        precondition(same(cache.image(forPage: u("https://d.check/presentation/3")), sheets))
        precondition(!cache.isSettled("d.check", for: u("https://d.check/presentation/3")))
        // A page whose icon is the site's writes nothing of its own.
        precondition(cache.store(dot(.green), forPage: u("https://d.check/other"), toDisk: false) == "d.check")
        precondition(cache.image(for: "d.check/other") == nil)
        // Sites never share: Meet's icon never becomes Google's.
        cache.store(google, forPage: u("https://www.google.check/"), toDisk: false)
        cache.store(meet, forPage: u("https://meet.google.check/abc-defg-hij"), toDisk: false)
        precondition(same(cache.image(forPage: u("https://www.google.check/search?q=x")), google))
        precondition(same(cache.image(forPage: u("https://meet.google.check/abc-defg-hij")), meet))
        // The root setting a new site icon unsettles the pages that shared the old one.
        cache.store(dot(.purple), forPage: u("https://d.check/"), toDisk: false)
        precondition(!cache.isSettled("d.check", for: u("https://d.check/other")))

        // Icons are kept outside Caches; what an older Vega saved there moves over.
        let files = FileManager.default
        let root = files.temporaryDirectory.appendingPathComponent("vega-favicon-move-\(UUID().uuidString)")
        defer { try? files.removeItem(at: root) }
        let support = root.appendingPathComponent("support"), caches = root.appendingPathComponent("caches")
        let old = caches.appendingPathComponent("Favicons")
        try! files.createDirectory(at: old, withIntermediateDirectories: true)
        try! Data("icon".utf8).write(to: old.appendingPathComponent("kept.png"))
        let moved = FaviconCache.prepare(support: support, caches: caches)
        precondition(moved.path == support.appendingPathComponent("Favicons").path)
        precondition(files.fileExists(atPath: moved.appendingPathComponent("kept.png").path), "old icons move over")
        precondition(FaviconCache.prepare(support: support, caches: caches) == moved)
        precondition(files.fileExists(atPath: moved.appendingPathComponent("kept.png").path), "a second launch keeps them")

        // The folder removed while Vega runs: the next icon still reaches the disk.
        precondition(!cache.directory.path.contains("com.vega.browser"), "a check never touches the real folder")
        try? files.removeItem(at: cache.directory)
        cache.store(dot(.red), for: "after.check")
        let written = cache.directory.appendingPathComponent(cache.fileName("after.check")).path
        for _ in 0..<100 where !files.fileExists(atPath: written) { Thread.sleep(forTimeInterval: 0.02) }
        precondition(files.fileExists(atPath: written), "written after the folder was removed")
        try? files.removeItem(at: cache.directory)
        print("FaviconKeyCheck ok")
    }
}
