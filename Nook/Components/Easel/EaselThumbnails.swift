// Licensed under GPL-3.0. See LICENSE.
//
//  EaselThumbnails.swift
//  Nook
//
//  FORK: the picture on an easel's page card. A page added from the browser uses a snapshot of the tab; a pasted or
//  dropped address uses the page's own share picture (its og:image), fetched without cookies and only from public
//  https hosts.
//

import AppKit
import Network

enum EaselThumbnails {
    private static let htmlLimit = 300_000
    private static let imageLimit = 5_000_000
    private static let agent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Safari/605.1.15"

    /// The share picture of a public https page, or nil.
    static func fetch(for page: URL) async -> NSImage? {
        guard isFetchable(page) else { return nil }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 8
        configuration.httpCookieStorage = nil
        let session = URLSession(configuration: configuration)
        guard let html = await read(page, limit: htmlLimit, session: session),
              let text = String(data: html, encoding: .utf8) ?? String(data: html, encoding: .isoLatin1),
              let imageURL = imageURL(inHTML: text, base: page), isFetchable(imageURL),
              let data = await read(imageURL, limit: imageLimit, session: session, complete: true) else { return nil }
        return NSImage(data: data)
    }

    /// A public https address: no local names and no raw IP numbers, so a card cannot point this at the user's network.
    static func isFetchable(_ url: URL) -> Bool {
        guard url.scheme?.lowercased() == "https", let host = url.host()?.lowercased(), host.contains("."),
              !host.hasSuffix(".local"), !host.hasSuffix(".localhost"), !host.hasSuffix(".internal"),
              IPv4Address(host) == nil, IPv6Address(host) == nil else { return false }
        return true
    }

    /// The first `limit` bytes. With `complete`, a longer body is refused instead of cut.
    private static func read(_ url: URL, limit: Int, session: URLSession, complete: Bool = false) async -> Data? {
        var request = URLRequest(url: url)
        request.setValue(agent, forHTTPHeaderField: "User-Agent")
        guard let (bytes, response) = try? await session.bytes(for: request),
              (response as? HTTPURLResponse).map({ (200..<300).contains($0.statusCode) }) ?? false else { return nil }
        var data = Data()
        do {
            for try await byte in bytes {
                data.append(byte)
                if data.count >= limit { return complete ? nil : data }
            }
        } catch { return data.isEmpty || complete ? nil : data }
        return data
    }

    /// The address in the page's share-picture tags, resolved against the page's own address.
    static func imageURL(inHTML html: String, base: URL) -> URL? {
        guard let tags = try? NSRegularExpression(pattern: "<meta\\s[^>]*>", options: .caseInsensitive) else { return nil }
        var found: [String: String] = [:]
        for match in tags.matches(in: html, range: NSRange(html.startIndex..., in: html)) {
            guard let range = Range(match.range, in: html) else { continue }
            let tag = String(html[range])
            guard let key = attribute("property", in: tag) ?? attribute("name", in: tag), let content = attribute("content", in: tag) else { continue }
            if found[key.lowercased()] == nil { found[key.lowercased()] = content }
        }
        for key in ["og:image:secure_url", "og:image", "og:image:url", "twitter:image", "twitter:image:src"] {
            guard let value = found[key]?.replacingOccurrences(of: "&amp;", with: "&"), !value.isEmpty,
                  let url = URL(string: value, relativeTo: base)?.absoluteURL else { continue }
            return url
        }
        return nil
    }

    private static func attribute(_ name: String, in tag: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: "\\b\(name)\\s*=\\s*(?:\"([^\"]*)\"|'([^']*)')", options: .caseInsensitive),
              let match = regex.firstMatch(in: tag, range: NSRange(tag.startIndex..., in: tag)) else { return nil }
        for group in 1...2 {
            if let range = Range(match.range(at: group), in: tag) { return String(tag[range]) }
        }
        return nil
    }
}
