// Licensed under GPL-3.0. See LICENSE.
//
//  PageSession+FaviconDOM.swift
//  NookWeb
//
//  Icon discovery from the loaded page's own <link> tags. Sites that answer a script's request
//  with 403 (Behance, Crunchyroll and others) still show the page, and its icon links, to the
//  web view, and the icon files themselves are rarely blocked.
//

#if os(macOS)
import Foundation
import WebKit
import SwiftUI

extension PageSession {
    private static let iconLinksScript = """
    Array.from(document.querySelectorAll('link[rel~="icon"],link[rel^="apple-touch-icon"]'))
      .map(l => ({href: l.href, rel: l.rel, sizes: l.sizes ? l.sizes.value : '', type: l.type || ''}))
    """

    private static func sameSite(_ current: URL?, _ page: URL) -> Bool {
        current?.host()?.lowercased() == page.host()?.lowercased()
    }

    /// Stores and shows the best icon the loaded page declares. False when the page has none
    /// we can use (not loaded yet, only SVG, download blocked).
    /// `live`: the page swapped its icon while open (Gmail's unread count). As browsers do, the icon link the page set
    /// last is the one shown, data: pictures included, and it is shown only, not kept: a count is out of date next time.
    @MainActor
    func fetchFaviconFromDOM(for pageURL: URL, live: Bool = false) async -> Bool {
        guard let webView = primaryWebView,
              let raw = try? await webView.evaluateJavaScript(Self.iconLinksScript) as? [[String: String]] else { return false }
        // The page can move on (Behance sends a visitor to Adobe's sign-in) between the load and this reply: its icon links
        // are then another site's, and they must not be stored under this address.
        guard Self.sameSite(webView.url, pageURL) else { return false }
        var seen = Set<String>()
        let links: [(href: String, edge: Int, touch: Bool)] = raw.compactMap { entry in
            guard let href = entry["href"], let url = URL(string: href),
                  url.scheme == "https" || url.scheme == "http" || (live && Self.isDataImage(href)),
                  !href.lowercased().contains(".svg"), !href.lowercased().hasPrefix("data:image/svg"), entry["type"] != "image/svg+xml",
                  seen.insert(href).inserted else { return nil }
            let touch = (entry["rel"] ?? "").hasPrefix("apple-touch-icon")
            if live, touch { return nil }
            // "180x180" or "16x16 32x32": the biggest declared edge; undeclared sorts last.
            let edge = (entry["sizes"] ?? "").split(separator: " ")
                .compactMap { Int($0.split(separator: "x").first ?? "") }.max() ?? 0
            return (href, edge, touch)
        }
        let ordered = live ? Array(links.reversed().prefix(2)) : Array(links.sorted(by: { $0.edge > $1.edge }).prefix(4))
        var best: (image: PlatformImage, rank: IconRank)?
        for link in ordered {
            var image: PlatformImage?
            if Self.isDataImage(link.href) { image = Self.dataImage(link.href) }
            else if let url = URL(string: link.href) { image = await Self.downloadImage(from: url, isPrivate: isPrivate) }
            guard let image else { continue }
            let rank = IconRank(image, touchIcon: link.touch)
            if rank.usable, !image.isBlank, best == nil || rank > best!.rank { best = (image, rank) }
            if live, best != nil { break }
        }
        guard Self.sameSite(webView.url, pageURL),
              let icon = best?.image.trimmedToContent().downscaled(toEdge: FaviconCache.maxStoredEdge) else { return false }
        if live {
            show(icon, for: pageURL)
            return true
        }
        // Kept for this page (and its site, when it is the site's first or its root). A private page's host must not
        // reach the favicon folder.
        let key = FaviconCache.shared.store(icon, forPage: pageURL, toDisk: !isPrivate)
        show(key.flatMap { FaviconCache.shared.image(for: $0) } ?? icon, for: pageURL)
        return true
    }

    private static func isDataImage(_ href: String) -> Bool { href.lowercased().hasPrefix("data:image/") }

    /// A base64 data: picture, as badge libraries draw a count onto the icon. Capped so a page can't hand over a huge one.
    private static func dataImage(_ href: String) -> PlatformImage? {
        guard href.count < 1_000_000, let comma = href.firstIndex(of: ","), href[..<comma].lowercased().hasSuffix(";base64"),
              let data = Data(base64Encoded: String(href[href.index(after: comma)...])) else { return nil }
        return PlatformImage(data: data)
    }
}
#endif
