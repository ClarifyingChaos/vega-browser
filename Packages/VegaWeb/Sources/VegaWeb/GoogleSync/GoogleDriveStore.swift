// Licensed under GPL-3.0. See LICENSE.
//
//  GoogleDriveStore.swift
//  VegaWeb
//
//  FORK: the sync files in Google Drive's hidden app-data folder: only Vega can see them, they
//  don't show in the person's Drive, and Google can't read the password files (encrypted).
//  Drive's app-data folder is flat, so "devices/<id>.json" is stored as "devices__<id>.json".
//

import Foundation
#if canImport(VegaTabsCore)
import VegaTabsCore
#endif

/// What Drive holds, listed once per round and reused, with the files already downloaded. A round used to cost a
/// search and a download for every file it touched, though almost nothing had changed; now a file is downloaded
/// only when its checksum is not the one already in hand.
final class DriveIndex: @unchecked Sendable {
    struct Entry { var id: String; var stamp: String }
    private let lock = NSLock()
    private var entries: [String: Entry] = [:]
    private var fetchedAt = Date.distantPast
    private var bodies: [String: (stamp: String, data: Data)] = [:]

    func fresh(ttl: TimeInterval) -> [String: Entry]? {
        lock.withLock { Date().timeIntervalSince(fetchedAt) < ttl ? entries : nil }
    }
    func replace(with new: [String: Entry]) {
        lock.withLock { entries = new; fetchedAt = Date(); bodies = bodies.filter { id, body in new.values.contains { $0.id == id && $0.stamp == body.stamp } } }
    }
    func record(name: String, _ entry: Entry, data: Data) {
        lock.withLock { entries[name] = entry; bodies[entry.id] = (entry.stamp, data) }
    }
    func body(for entry: Entry) -> Data? {
        lock.withLock { bodies[entry.id].flatMap { $0.stamp == entry.stamp ? $0.data : nil } }
    }
    func keep(_ data: Data, for entry: Entry) { lock.withLock { bodies[entry.id] = (entry.stamp, data) } }
}

public struct GoogleDriveStore: SyncBlobStore {
    /// Shared by every store value: the account's token closure is the only thing a new value carries. Another account's
    /// files have other ids, so nothing here can be mistaken for them.
    private static let index = DriveIndex()
    /// How long one listing serves the lookups of a round.
    private static let indexTTL: TimeInterval = 8

    /// A valid access token, refreshed when needed.
    let token: @Sendable () async throws -> String

    public init(token: @escaping @Sendable () async throws -> String) { self.token = token }

    public static func flatName(_ path: String) -> String { path.replacingOccurrences(of: "/", with: "__") }

    /// Drive query strings quote with single quotes.
    static func quoted(_ s: String) -> String { "'" + s.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "'", with: "\\'") + "'" }

    private func request(_ url: URL, method: String = "GET", body: Data? = nil, contentType: String? = nil) async throws -> Data {
        var r = URLRequest(url: url)
        r.httpMethod = method
        r.httpBody = body
        r.setValue("Bearer \(try await token())", forHTTPHeaderField: "Authorization")
        if let contentType { r.setValue(contentType, forHTTPHeaderField: "Content-Type") }
        let (data, response) = try await URLSession.shared.data(for: r)
        guard let status = (response as? HTTPURLResponse)?.statusCode else { throw URLError(.badServerResponse) }
        if status == 404 { throw DriveError.notFound }
        guard (200..<300).contains(status) else {
            let message = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["error"] as? [String: Any]
            throw DriveError.http(status, (message?["message"] as? String) ?? "")
        }
        return data
    }

    enum DriveError: LocalizedError {
        case notFound, http(Int, String)
        var errorDescription: String? {
            switch self {
            case .notFound: return "Not found in Google Drive."
            case .http(let code, let message): return "Google Drive said \(code)\(message.isEmpty ? "" : ": " + message)"
            }
        }
    }

    /// Every file in the app-data folder, from one request. The checksum is the stamp: it changes when the content does.
    private func catalog() async throws -> [String: DriveIndex.Entry] {
        if let hit = Self.index.fresh(ttl: Self.indexTTL) { return hit }
        var c = URLComponents(string: "https://www.googleapis.com/drive/v3/files")!
        c.queryItems = [.init(name: "spaces", value: "appDataFolder"), .init(name: "q", value: "trashed = false"),
                        .init(name: "fields", value: "files(id,name,modifiedTime,md5Checksum)"), .init(name: "pageSize", value: "1000")]
        let json = try JSONSerialization.jsonObject(with: try await request(c.url!)) as? [String: Any]
        var found: [String: DriveIndex.Entry] = [:]
        for file in json?["files"] as? [[String: Any]] ?? [] {
            guard let id = file["id"] as? String, let name = file["name"] as? String, found[name] == nil else { continue }
            found[name] = .init(id: id, stamp: Self.stamp(file))
        }
        Self.index.replace(with: found)
        return found
    }

    private static func stamp(_ file: [String: Any]) -> String {
        (file["md5Checksum"] as? String) ?? (file["modifiedTime"] as? String) ?? ""
    }

    public func put(_ path: String, _ data: Data) async throws {
        let name = Self.flatName(path)
        let fields = URLQueryItem(name: "fields", value: "id,modifiedTime,md5Checksum")
        let response: Data
        if let existing = try await catalog()[name] {
            var c = URLComponents(string: "https://www.googleapis.com/upload/drive/v3/files/\(existing.id)")!
            c.queryItems = [.init(name: "uploadType", value: "media"), fields]
            response = try await request(c.url!, method: "PATCH", body: data, contentType: "application/octet-stream")
        } else {
            // New file: metadata and content in one multipart request.
            let boundary = "vega-" + UUID().uuidString
            let metadata = try JSONSerialization.data(withJSONObject: ["name": name, "parents": ["appDataFolder"]])
            var body = Data()
            body.append(Data("--\(boundary)\r\nContent-Type: application/json; charset=UTF-8\r\n\r\n".utf8)); body.append(metadata)
            body.append(Data("\r\n--\(boundary)\r\nContent-Type: application/octet-stream\r\n\r\n".utf8)); body.append(data)
            body.append(Data("\r\n--\(boundary)--".utf8))
            var c = URLComponents(string: "https://www.googleapis.com/upload/drive/v3/files")!
            c.queryItems = [.init(name: "uploadType", value: "multipart"), fields]
            response = try await request(c.url!, method: "POST", body: body, contentType: "multipart/related; boundary=\(boundary)")
        }
        if let file = try? JSONSerialization.jsonObject(with: response) as? [String: Any], let id = file["id"] as? String {
            Self.index.record(name: name, .init(id: id, stamp: Self.stamp(file)), data: data)
        }
    }

    public func get(_ path: String) async throws -> Data? {
        guard let file = try await catalog()[Self.flatName(path)] else { return nil }
        if let have = Self.index.body(for: file) { return have }
        var c = URLComponents(string: "https://www.googleapis.com/drive/v3/files/\(file.id)")!
        c.queryItems = [.init(name: "alt", value: "media")]
        do {
            let data = try await request(c.url!)
            Self.index.keep(data, for: file)
            return data
        } catch DriveError.notFound { return nil }
    }

    public func list(_ directory: String) async throws -> (names: [String], pending: Int) {
        let prefix = Self.flatName(directory) + "__"
        return (try await catalog().keys.filter { $0.hasPrefix(prefix) }.map { String($0.dropFirst(prefix.count)) }, 0)
    }
}
