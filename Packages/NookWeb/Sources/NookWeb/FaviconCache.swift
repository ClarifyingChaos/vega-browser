// Licensed under GPL-3.0. See LICENSE.
//
//  FaviconCache.swift
//  Nook
//
//  Global favicon cache, shared across profiles by design to raise the hit rate and avoid
//  duplicate downloads. Memory LRU of 200 entries plus icons on disk at
//  ~/Library/Application Support/{bundle ID}/Favicons/{key}.png that survive relaunch. Disk I/O
//  runs on a background queue.
//

import CryptoKit
import Foundation
import SwiftUI

public final class FaviconCache: @unchecked Sendable {
    public static let shared = FaviconCache()

    public static let maxMemoryEntries = 200

    private struct Entry {
        let nsImage: PlatformImage
        let image: SwiftUI.Image
    }

    private var memory: [String: Entry] = [:]
    /// Insertion order for LRU eviction.
    private var order: [String] = []
    private let lock = NSLock()
    private let queue = DispatchQueue(label: "favicon.cache", attributes: .concurrent)

    public let directory: URL = {
        let files = FileManager.default
        // A command-line check has no bundle ID and must not touch the real app's folders.
        guard let id = Bundle.main.bundleIdentifier else {
            return files.temporaryDirectory.appendingPathComponent("vega-favicon-check", isDirectory: true)
        }
        return prepare(support: files.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent(id, isDirectory: true),
                       caches: files.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent(id, isDirectory: true))
    }()

    /// FORK: icons live in Application Support, not Caches: macOS and cleaner apps may empty Caches, and every favorite
    /// and tab then showed a globe until its page loaded again. Icons an older Vega saved in Caches move over once.
    static func prepare(support: URL, caches: URL) -> URL {
        let files = FileManager.default
        // "FaviconCache" held icons saved one per site, some from another page of it or a page it went on to (Google
        // showing Meet's icon). Page-keyed icons have their own folder and the old one goes.
        try? files.removeItem(at: caches.appendingPathComponent("FaviconCache", isDirectory: true))
        let dir = support.appendingPathComponent("Favicons", isDirectory: true)
        try? files.createDirectory(at: support, withIntermediateDirectories: true)
        // Fails, harmlessly, when there is nothing to move or the new folder is already there.
        try? files.moveItem(at: caches.appendingPathComponent("Favicons", isDirectory: true), to: dir)
        try? files.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private init() {}

    /// Cache key for a page: the host, plus `_port` when the port is not the scheme's default.
    public static func key(for url: URL) -> String? {
        guard let host = url.host else { return nil }
        guard let port = url.port, port != (url.scheme == "https" ? 443 : 80) else { return host }
        return "\(host)_\(port)"
    }

    /// FORK: the key for one page, as Chromium (so Arc and Dia) keeps an icon per page address, not per site:
    /// docs.google.com/spreadsheets and /document have different icons. The host key plus the path, without query or
    /// fragment; the site's root page is the host key itself, which is also the fallback for a page not seen yet.
    public static func pageKey(for url: URL) -> String? {
        guard let site = key(for: url) else { return nil }
        var path = url.path
        while path.hasSuffix("/") { path.removeLast() }
        return path.isEmpty ? site : site + path
    }

    /// Where to look for a page's icon: its own, then its site's.
    public static func lookupKeys(for url: URL) -> [String] {
        guard let page = pageKey(for: url), let site = key(for: url) else { return [] }
        return page == site ? [site] : [page, site]
    }

    /// https, with a dotted host name that is not an IP address, `localhost` or `.local`.
    static func isPublicHTTPS(_ url: URL) -> Bool {
        guard url.scheme == "https", let host = url.host?.lowercased(), host.contains("."),
              !host.hasSuffix(".local"), !host.contains(":"),
              host.contains(where: { $0.isLetter }) else { return false }
        return true
    }

    // MARK: - Lookup

    /// Memory cache only, synchronous. A read counts as use, so the entries evicted first are the
    /// ones nobody looks at, not the ones stored first (favorites are stored first).
    public func image(for key: String) -> PlatformImage? {
        lock.withLock { touch(key)?.nsImage }
    }

    /// Memory cache only, as a SwiftUI image.
    public func swiftUIImage(for key: String) -> SwiftUI.Image? {
        lock.withLock { touch(key)?.image }
    }

    /// Caller holds `lock`.
    private func touch(_ key: String) -> Entry? {
        guard let entry = memory[key] else { return nil }
        if let index = order.lastIndex(of: key), index != order.count - 1 {
            order.remove(at: index)
            order.append(key)
        }
        return entry
    }

    /// Memory first, then disk off the main thread. A disk hit is promoted to memory.
    public func cachedImage(for key: String) async -> PlatformImage? {
        if let hit = image(for: key) { return hit }
        return await withCheckedContinuation { continuation in
            queue.async {
                let image = self.readFromDisk(key)
                if let image { self.insert(Entry(nsImage: image, image: SwiftUI.Image(platformImage: image)), for: key) }
                continuation.resume(returning: image)
            }
        }
    }

    /// Synchronous disk read with promotion to memory. For startup restore of a few visible rows.
    public func imageFromDiskSync(for key: String) -> PlatformImage? {
        guard let image = readFromDisk(key) else { return nil }
        insert(Entry(nsImage: image, image: SwiftUI.Image(platformImage: image)), for: key)
        return image
    }

    // MARK: - Pages

    /// Memory only: the page's own icon, else its site's.
    public func image(forPage url: URL) -> PlatformImage? {
        Self.lookupKeys(for: url).lazy.compactMap { self.image(for: $0) }.first
    }

    public func swiftUIImage(forPage url: URL) -> SwiftUI.Image? {
        Self.lookupKeys(for: url).lazy.compactMap { self.swiftUIImage(for: $0) }.first
    }

    /// Memory, then disk synchronously. For the few rows shown at launch.
    public func imageFromDiskSync(forPage url: URL) -> PlatformImage? {
        for key in Self.lookupKeys(for: url) {
            if let hit = image(for: key) ?? imageFromDiskSync(for: key) { return hit }
        }
        return nil
    }

    /// The page's own icon, else its site's, with the key it was found under.
    public func cachedEntry(forPage url: URL) async -> (key: String, image: PlatformImage)? {
        for key in Self.lookupKeys(for: url) {
            if let hit = await cachedImage(for: key) { return (key, hit) }
        }
        return nil
    }

    public func cachedImage(forPage url: URL) async -> PlatformImage? {
        await cachedEntry(forPage: url)?.image
    }

    /// Pages whose own icon was checked this run and is the same as their site's, so the site's stands for them.
    private var sameAsSite = Set<String>()

    /// True when `key` really is this page's icon: its own entry, or its site's once the page was seen to use the same one.
    /// Else the page has only borrowed its site's icon and should look at its own links.
    public func isSettled(_ key: String, for url: URL) -> Bool {
        guard let page = Self.pageKey(for: url) else { return false }
        return key == page || lock.withLock { sameAsSite.contains(page) }
    }

    /// Keeps an icon a page declared. The site's root page, and the first page seen on a site, set the site's icon; any
    /// other page keeps its own only when it differs from the site's, so a site's thousand pages don't each write a file.
    /// Returns the key the page's icon is now found under.
    @discardableResult
    public func store(_ image: PlatformImage, forPage url: URL, toDisk: Bool = true) -> String? {
        guard let page = Self.pageKey(for: url), let site = Self.key(for: url) else { return nil }
        let siteIcon = page == site ? nil : (self.image(for: site) ?? imageFromDiskSync(for: site))
        guard let siteIcon else {
            // A new site icon: pages seen to share the old one must look at their own links again.
            lock.withLock {
                sameAsSite = sameAsSite.filter { !$0.hasPrefix(site + "/") }
                if page != site { sameAsSite.insert(page) }
            }
            store(image, for: site, toDisk: toDisk)
            return site
        }
        if let data = image.pngData(), data == siteIcon.pngData() {
            remove(page)
            lock.withLock { _ = sameAsSite.insert(page) }
            return site
        }
        store(image, for: page, toDisk: toDisk)
        return page
    }

    /// Drops one entry from memory and disk.
    func remove(_ key: String) {
        lock.withLock {
            memory.removeValue(forKey: key)
            order.removeAll { $0 == key }
        }
        let url = fileURL(key)
        queue.async(flags: .barrier) { try? FileManager.default.removeItem(at: url) }
    }

    /// How long a stored favicon is trusted before a visit fetches it again.
    public static let maxAge: TimeInterval = 24 * 60 * 60

    /// True when the disk copy is older than `maxAge`. Memory-only entries (private pages) are never stale.
    public func isStale(_ key: String) async -> Bool {
        let url = fileURL(key)
        return await withCheckedContinuation { continuation in
            queue.async {
                let modified = (try? FileManager.default.attributesOfItem(atPath: url.path))?[.modificationDate] as? Date
                continuation.resume(returning: modified.map { -$0.timeIntervalSinceNow > Self.maxAge } ?? false)
            }
        }
    }

    // MARK: - Store

    /// Stores in memory and writes a PNG to disk.
    public func store(_ image: PlatformImage, for key: String) {
        store(image, for: key, toDisk: true)
    }

    func store(_ image: PlatformImage, for key: String, toDisk: Bool) {
        insert(Entry(nsImage: image, image: SwiftUI.Image(platformImage: image)), for: key)
        guard toDisk else { return }
        // PNG encoding is CPU work, not I/O; do it on the caller.
        guard let png = image.pngData() else { return }
        let url = fileURL(key)
        queue.async(flags: .barrier) {
            // The folder can be removed while Vega runs; without this every later write failed unseen.
            try? FileManager.default.createDirectory(at: self.directory, withIntermediateDirectories: true)
            // Atomic, so a crash mid-write cannot leave a cut-off PNG.
            try? png.write(to: url, options: .atomic)
            self.storesSinceTrim += 1
            if self.storesSinceTrim >= 50 { self.storesSinceTrim = 0; self.trimDisk() }
        }
    }

    // MARK: - Maintenance

    public func clear() {
        lock.withLock {
            memory.removeAll()
            order.removeAll()
            sameAsSite.removeAll()
        }
        let dir = directory
        queue.async(flags: .barrier) {
            try? FileManager.default.removeItem(at: dir)
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
    }

    /// Entry counts in memory and on disk.
    public func stats() -> (memory: Int, disk: Int) {
        let memoryCount = lock.withLock { memory.count }
        let diskCount = (try? FileManager.default.contentsOfDirectory(atPath: directory.path).count) ?? 0
        return (memoryCount, diskCount)
    }

    /// Keys currently in memory.
    public var memoryKeys: [String] {
        lock.withLock { Array(memory.keys) }
    }

    // MARK: - Private

    /// How many icons the disk keeps. Memory holds fewer; leaving memory no longer deletes a file.
    public static let maxDiskEntries = 1000
    private var storesSinceTrim = 0

    /// Deletes the oldest-written files beyond the cap. Runs on `queue` with the barrier.
    private func trimDisk() {
        let keys: [URLResourceKey] = [.contentModificationDateKey]
        guard let files = try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: keys),
              files.count > Self.maxDiskEntries else { return }
        func written(_ url: URL) -> Date { (try? url.resourceValues(forKeys: Set(keys)).contentModificationDate) ?? .distantPast }
        for url in files.sorted(by: { written($0) < written($1) }).prefix(files.count - Self.maxDiskEntries + 50) {
            try? FileManager.default.removeItem(at: url)
        }
    }

    private func insert(_ entry: Entry, for key: String) {
        lock.withLock {
            memory[key] = entry
            order.removeAll { $0 == key }
            order.append(key)
            if memory.count > Self.maxMemoryEntries {
                let count = memory.count - Self.maxMemoryEntries + 20
                for old in order.prefix(count) { memory.removeValue(forKey: old) }
                order.removeFirst(min(count, order.count))
            }
        }
    }

    private func fileURL(_ key: String) -> URL {
        directory.appendingPathComponent(fileName(key))
    }

    /// Only [A-Za-z0-9._-] survive; the rest (IPv6 colons, slashes) become `_`. A page key also gets a short digest of
    /// itself, so /a/b and /a_b stay apart and a long path stays under the file-name limit.
    func fileName(_ key: String) -> String {
        let safe = String(key.unicodeScalars.map { c -> Character in
            let ok = c.isASCII && (c.properties.isAlphabetic || ("0"..."9").contains(c) || "._-".unicodeScalars.contains(c))
            return ok ? Character(c) : "_"
        })
        guard key.contains("/") else { return safe + ".png" }
        let digest = SHA256.hash(data: Data(key.utf8)).prefix(8).map { String(format: "%02x", $0) }.joined()
        return String(safe.prefix(100)) + "-" + digest + ".png"
    }

    private func readFromDisk(_ key: String) -> PlatformImage? {
        guard let data = try? Data(contentsOf: fileURL(key)) else { return nil }
        return PlatformImage(data: data)
    }
}
