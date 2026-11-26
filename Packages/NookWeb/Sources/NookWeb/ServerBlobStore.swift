// Licensed under GPL-3.0. See LICENSE.
//
//  ServerBlobStore.swift
//  NookWeb
//
//  FORK: sync through Vega's own server (server/ in this repository) instead of iCloud Drive or Google Drive. The same
//  files, already sealed on the Mac, so the server reads nothing; a file is downloaded again only when its checksum
//  changed, and a live connection says when another Mac wrote, so changes arrive in seconds.
//

import Foundation
#if canImport(NookTabsCore)
import NookTabsCore
#endif

public struct ServerBlobStore: SyncBlobStore {
    public let base: URL
    let token: @Sendable () async throws -> String

    public init(base: URL, token: @escaping @Sendable () async throws -> String) {
        self.base = base
        self.token = token
    }

    enum ServerError: LocalizedError {
        case http(Int)
        var errorDescription: String? {
            switch self {
            case .http(401): return "Vega Sync asks you to sign in with Google again."
            case .http(let code): return "Vega Sync answered \(code)."
            }
        }
    }

    private static let bodies = ServerBodies()

    private func request(_ path: String, method: String = "GET", body: Data? = nil, etag: String? = nil) async throws -> (Data, HTTPURLResponse) {
        guard let url = URL(string: path, relativeTo: base) else { throw URLError(.badURL) }
        var r = URLRequest(url: url, timeoutInterval: 30)
        r.httpMethod = method
        r.httpBody = body
        r.setValue("Bearer \(try await token())", forHTTPHeaderField: "Authorization")
        if let etag { r.setValue("\"\(etag)\"", forHTTPHeaderField: "If-None-Match") }
        if body != nil { r.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type") }
        let (data, response) = try await URLSession.shared.data(for: r)
        guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        return (data, http)
    }

    private func blobPath(_ path: String) -> String {
        "v1/blobs/" + (path.addingPercentEncoding(withAllowedCharacters: .alphanumerics.union(.init(charactersIn: "._-"))) ?? path)
    }

    public func put(_ path: String, _ data: Data) async throws {
        let (_, response) = try await request(blobPath(path), method: "PUT", body: data)
        guard response.statusCode == 200 else { throw ServerError.http(response.statusCode) }
        Self.bodies.forget(path)
    }

    public func get(_ path: String) async throws -> Data? {
        let known = Self.bodies.body(path)
        let (data, response) = try await request(blobPath(path), etag: known?.stamp)
        switch response.statusCode {
        case 304: return known?.data
        case 404: return nil
        case 200:
            if let tag = response.value(forHTTPHeaderField: "ETag")?.trimmingCharacters(in: CharacterSet(charactersIn: "\"")) {
                Self.bodies.keep(path, stamp: tag, data: data)
            }
            return data
        default: throw ServerError.http(response.statusCode)
        }
    }

    public func list(_ directory: String) async throws -> (names: [String], pending: Int) {
        let query = directory.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? directory
        let (data, response) = try await request("v1/list?dir=\(query)")
        guard response.statusCode == 200 else { throw ServerError.http(response.statusCode) }
        let files = ((try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["files"] as? [[String: Any]]) ?? []
        return (files.compactMap { $0["name"] as? String }, 0)
    }

    /// A live connection that calls `changed` whenever another Mac writes. Reconnects after a drop, more slowly each time.
    public func live(_ changed: @escaping @Sendable () -> Void) -> ServerLive { ServerLive(store: self, changed: changed) }

    func liveRequest() async throws -> URLRequest {
        guard var parts = URLComponents(url: base.appendingPathComponent("v1/live"), resolvingAgainstBaseURL: true) else { throw URLError(.badURL) }
        parts.scheme = parts.scheme == "http" ? "ws" : "wss"
        guard let url = parts.url else { throw URLError(.badURL) }
        var r = URLRequest(url: url)
        r.setValue("Bearer \(try await token())", forHTTPHeaderField: "Authorization")
        return r
    }
}

/// Files already downloaded, by path, with the checksum they had.
final class ServerBodies: @unchecked Sendable {
    private let lock = NSLock()
    private var store: [String: (stamp: String, data: Data)] = [:]
    func body(_ path: String) -> (stamp: String, data: Data)? { lock.withLock { store[path] } }
    func keep(_ path: String, stamp: String, data: Data) { lock.withLock { store[path] = (stamp, data) } }
    func forget(_ path: String) { lock.withLock { store[path] = nil } }
}

public final class ServerLive: @unchecked Sendable {
    private let store: ServerBlobStore
    private let changed: @Sendable () -> Void
    private var task: Task<Void, Never>?

    init(store: ServerBlobStore, changed: @escaping @Sendable () -> Void) {
        self.store = store
        self.changed = changed
        task = Task.detached(priority: .utility) { [weak self] in await self?.run() }
    }

    public func stop() { task?.cancel(); task = nil }
    deinit { task?.cancel() }

    private func run() async {
        var delay: Double = 2
        while !Task.isCancelled {
            if let request = try? await store.liveRequest() {
                let socket = URLSession.shared.webSocketTask(with: request)
                socket.resume()
                // The server answers "pong": proof the connection stands.
                socket.send(.string("ping")) { _ in }
                while !Task.isCancelled, let message = try? await socket.receive() {
                    // Only a message from the server resets the wait. Resetting on every attempt had a refused sign-in
                    // trying again every 2 s for good.
                    delay = 2
                    if case .string(let text) = message, text != "pong" { changed() }
                }
                socket.cancel(with: .goingAway, reason: nil)
            }
            try? await Task.sleep(for: .seconds(delay))
            delay = min(delay * 2, 120)
        }
    }
}
