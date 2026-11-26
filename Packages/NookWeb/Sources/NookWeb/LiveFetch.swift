// Licensed under GPL-3.0. See LICENSE.
//
//  LiveFetch.swift
//  Nook
//
//  The signed-in request behind a favorite's pull request card (GitHubPulls.swift). It sends the
//  space's own cookies for the asked domains only.
//

import Foundation
import NookTabsCore

enum LiveFetch {
    enum Failure: Error { case signedOut, failed }

    static let session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpCookieStorage = nil
        configuration.httpShouldSetCookies = false
        configuration.urlCache = nil
        configuration.timeoutIntervalForRequest = 20
        return URLSession(configuration: configuration, delegate: NoRedirects(), delegateQueue: nil)
    }()

    /// A signed-out request redirects to the login page; following it would carry the cookies on.
    private final class NoRedirects: NSObject, URLSessionTaskDelegate {
        func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest) async -> URLRequest? {
            nil
        }
    }

    /// GET with only the cookies set for `domains`. Signed out (no cookies) throws before any request.
    static func get(_ url: URL, cookies: [HTTPCookie], domains: Set<String>, headers: [String: String] = [:]) async throws -> (Data, Int) {
        let ours = cookies.filter { domains.contains($0.domain) }
        guard !ours.isEmpty else { throw Failure.signedOut }
        var request = URLRequest(url: url)
        request.allHTTPHeaderFields = HTTPCookie.requestHeaderFields(with: ours).merging(headers) { $1 }
        if let agent = PlatformUserAgent.custom { request.setValue(agent, forHTTPHeaderField: "User-Agent") }
        guard let (data, response) = try? await session.data(for: request),
              let status = (response as? HTTPURLResponse)?.statusCode else { throw Failure.failed }
        return (data, status)
    }

    /// What github.com's own pages send with a JSON route request.
    static let gitHubJSONHeaders = [
        "Accept": "application/json",
        "X-Requested-With": "XMLHttpRequest",
        "GitHub-Verified-Fetch": "true",
    ]
}
