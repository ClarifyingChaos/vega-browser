// Licensed under GPL-3.0. See LICENSE.
//
//  TidyTitles.swift
//  NookWeb
//
//  Trims a page title for the sidebar row: drops the site's own suffix, the unread counter and
//  the account address, and shows a search page as its query. Display only: the stored title,
//  history and search keep the page's own. The rule shape follows Arc's `tidyTitles` (per host a
//  site name and ordered rules; a rule matches on path or fragment, then changes the title); the
//  table is Nook's own. Foundation only, checked by `Checks/TidyTitlesCheck.swift`.
//

import Foundation

public enum TidyTitles {
    public struct Result: Equatable, Sendable {
        public let title: String
        /// The site's short name, set for hosts that have rules.
        public let siteName: String?
        /// True when the row should show `siteName` beside the title (search pages).
        public let showsSite: Bool
    }

    /// The title to show for `url`; `title` itself when nothing applies.
    public static func tidy(title: String, url: URL?) -> String {
        result(title: title, url: url).title
    }

    public static func result(title: String, url: URL?) -> Result {
        let key = (title + "\u{0}" + (url?.absoluteString ?? "")) as NSString
        if let hit = cache.object(forKey: key) { return hit.value }
        let raw = compute(title: title, url: url)
        let value = Result(title: shortened(raw.title), siteName: raw.siteName, showsSite: raw.showsSite)
        cache.setObject(Box(value), forKey: key)
        return value
    }

    private final class Box {
        let value: Result
        init(_ value: Result) { self.value = value }
    }

    /// Rows ask on every render; a few hundred recent answers cover the sidebar.
    private static let cache: NSCache<NSString, Box> = {
        let cache = NSCache<NSString, Box>()
        cache.countLimit = 400
        return cache
    }()

    private static func compute(title: String, url: URL?) -> Result {
        let stripped = replacing(counter, in: title)
        let base = stripped.isEmpty ? title : stripped
        guard let url, url.scheme == "http" || url.scheme == "https", let host = url.host?.lowercased() else {
            return Result(title: base, siteName: nil, showsSite: false)
        }
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let path = url.path.isEmpty ? "/" : url.path
        let fragment = (components?.fragment ?? "").lowercased()
        for site in sites where site.matches(host: host) {
            guard let rule = site.rules.first(where: { $0.match.matches(path: path, fragment: fragment) }),
                  let changed = rule.title.apply(to: stripped, url: components) else { continue }
            return Result(title: changed.isEmpty ? base : changed, siteName: site.siteName, showsSite: rule.title.isQuery)
        }
        return Result(title: droppingSiteName(base, host: host), siteName: nil, showsSite: false)
    }

    // MARK: - Any site

    /// Longest row title, in characters; a longer one is cut at a word and ends in "…".
    static let maxLength = 28

    static func shortened(_ title: String) -> String {
        let title = title.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        guard title.count > maxLength else { return title }
        var cut = String(title.prefix(maxLength))
        // A break between parts ("Title · Section") is the cleanest place to stop, with no "…".
        // Looks a little past the cut, so a separator right at the limit still counts.
        let ns = String(title.prefix(maxLength + 3)) as NSString
        if let last = separator.matches(in: ns as String, range: NSRange(location: 0, length: ns.length)).last(where: { $0.range.location <= maxLength }),
           last.range.location >= maxLength / 3 {
            return ns.substring(to: last.range.location)
        }
        // A cut that already ends at a word keeps that word.
        let endsAtWord = title[title.index(title.startIndex, offsetBy: maxLength)] == " "
        if !endsAtWord, let space = cut.lastIndex(of: " "), cut.distance(from: cut.startIndex, to: space) >= maxLength / 2 { cut = String(cut[..<space]) }
        return cut.trimmingCharacters(in: CharacterSet.punctuationCharacters.union(.whitespaces).subtracting(CharacterSet(charactersIn: ")?!\"'"))) + "\u{2026}"
    }

    /// " | ", " - ", " – ", " — ", " · ", " : ", " • " between a page's title and its site's name.
    private static let separator = re(#"\s+[|\-\x{2013}\x{2014}\x{00B7}:\x{2022}]\s+"#)

    /// Drops the site's own name from the end ("Best laptops | The Verge"), or else from the start ("Apple - iPhone"):
    /// a short part (four words at most) that holds the host's name. The rest is kept as the page wrote it.
    static func droppingSiteName(_ title: String, host: String) -> String {
        let brand = brandName(of: host)
        guard brand.count >= 3 else { return title }
        let ns = title as NSString
        let cuts = separator.matches(in: title, range: NSRange(location: 0, length: ns.length)).map(\.range)
        guard !cuts.isEmpty else { return title }
        var parts: [String] = [], start = 0
        for cut in cuts { parts.append(ns.substring(with: NSRange(location: start, length: cut.location - start))); start = cut.location + cut.length }
        parts.append(ns.substring(from: start))
        func isSiteName(_ part: String) -> Bool {
            let words = part.split(separator: " ").count
            let squashed = part.lowercased().filter { $0.isLetter || $0.isNumber }
            return words <= 4 && squashed.count >= 3 && (squashed.contains(brand) || brand.contains(squashed))
        }
        var kept = parts
        while kept.count > 1, let last = kept.last, isSiteName(last) { kept.removeLast() }
        if kept.count == parts.count, kept.count > 1, isSiteName(kept[0]) { kept.removeFirst() }
        guard kept.count < parts.count else { return title }
        // Joined back with the page's own separators.
        let firstKept = parts.firstIndex(of: kept[0]) ?? 0
        var out = kept[0]
        for i in 1..<kept.count { out += ns.substring(with: cuts[firstKept + i - 1]) + kept[i] }
        return out.trimmingCharacters(in: .whitespaces)
    }

    /// "theverge" for www.theverge.com, "bbc" for news.bbc.co.uk.
    private static func brandName(of host: String) -> String {
        var labels = host.split(separator: ".").map(String.init)
        if labels.count > 1 { labels.removeLast() }
        if labels.count > 1, ["co", "com", "org", "net", "ac", "gov", "edu", "ne", "or"].contains(labels.last!) { labels.removeLast() }
        return (labels.last ?? "").filter { $0.isLetter || $0.isNumber }
    }

    // MARK: - Schema

    struct Site {
        let hosts: [String]
        let siteName: String
        let rules: [Rule]
        /// Each host with its leading dot, so a suffix test builds no strings per call.
        let dottedHosts: [(host: String, dotted: String)]

        init(hosts: [String], siteName: String, rules: [Rule]) {
            self.hosts = hosts
            self.siteName = siteName
            self.rules = rules
            dottedHosts = hosts.map { ($0, "." + $0) }
        }

        func matches(host: String) -> Bool {
            dottedHosts.contains { host == $0.host || host.hasSuffix($0.dotted) }
        }
    }

    struct Rule {
        let match: Match
        let title: Change
    }

    enum Match {
        case pathEquals(String)
        case pathContainsRegex(NSRegularExpression)
        case fragmentEquals(String)
        case fragmentContainsRegex(NSRegularExpression)

        func matches(path: String, fragment: String) -> Bool {
            switch self {
            case .pathEquals(let value): return path == value
            case .pathContainsRegex(let regex): return TidyTitles.found(regex, in: path)
            case .fragmentEquals(let value): return fragment == value
            case .fragmentContainsRegex(let regex): return TidyTitles.found(regex, in: fragment)
            }
        }
    }

    enum Change {
        case always(String)
        case removingPattern(NSRegularExpression)
        case removingPatterns([NSRegularExpression])
        /// Nook's addition: the title becomes this URL query parameter's value.
        case queryParameter(String)

        var isQuery: Bool {
            if case .queryParameter = self { return true }
            return false
        }

        func apply(to title: String, url: URLComponents?) -> String? {
            switch self {
            case .always(let value): return value
            case .removingPattern(let regex): return TidyTitles.replacing(regex, in: title)
            case .removingPatterns(let list): return list.reduce(title) { TidyTitles.replacing($1, in: $0) }
            case .queryParameter(let name):
                // Forms encode spaces as `+`; a real plus arrives as %2B and survives.
                guard let raw = url?.percentEncodedQueryItems?.first(where: { $0.name == name })?.value,
                      let query = raw.replacingOccurrences(of: "+", with: " ").removingPercentEncoding?
                        .trimmingCharacters(in: .whitespacesAndNewlines), !query.isEmpty else { return nil }
                return query
            }
        }
    }

    // MARK: - Helpers

    private static func re(_ pattern: String) -> NSRegularExpression {
        // swiftlint:disable:next force_try
        try! NSRegularExpression(pattern: pattern)
    }

    fileprivate static func found(_ regex: NSRegularExpression, in text: String) -> Bool {
        regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) != nil
    }

    fileprivate static func replacing(_ regex: NSRegularExpression, in text: String) -> String {
        regex.stringByReplacingMatches(in: text, range: NSRange(text.startIndex..., in: text), withTemplate: "")
            .trimmingCharacters(in: .whitespaces)
    }

    private static func removing(_ patterns: String...) -> Change { .removingPatterns(patterns.map(re)) }
    private static func anyPath() -> Match { .pathContainsRegex(re("^/")) }
    private static func under(_ prefix: String) -> Match { .pathContainsRegex(re("^" + prefix)) }

    /// A leading unread count: "(3) ", "(12+) ".
    private static let counter = re(#"^\(\d+\+?\)\s*"#)

    private static let googleSearchHosts = [
        "google.com", "google.co.uk", "google.ca", "google.com.au", "google.de", "google.fr", "google.es",
        "google.it", "google.nl", "google.co.jp", "google.co.in", "google.com.br", "google.com.mx",
        "google.pl", "google.se", "google.ch", "google.at", "google.ie", "google.co.nz", "google.co.za",
    ]

    private static let amazonHosts = [
        "amazon.com", "amazon.co.uk", "amazon.de", "amazon.ca", "amazon.fr", "amazon.it", "amazon.es",
        "amazon.co.jp", "amazon.com.au", "amazon.in", "amazon.com.br", "amazon.com.mx", "amazon.nl",
        "amazon.se", "amazon.pl", "amazon.com.tr",
    ]

    /// Gmail's tail: "- me@example.com - Gmail", and a count in brackets after the folder.
    private static let gmailTail = [#"\s*-\s*[^\s@]+@[^\s@]+\s*(-\s*Gmail)?$"#, #"\s*-\s*Gmail$"#]
    private static let gmail = removing(gmailTail[0], gmailTail[1])
    /// A folder page also drops the count in brackets; a message subject keeps its own.
    private static let gmailFolder = removing(gmailTail[0], gmailTail[1], #"\s*\(\d+\)$"#)

    private static let sites: [Site] = [
        Site(hosts: ["mail.google.com"], siteName: "Gmail", rules: [
            Rule(match: .fragmentContainsRegex(re("^((inbox|sent|drafts|starred|snoozed|imp|scheduled|all|spam|trash|chats)(\\?.*)?|(label|category|search)/[^/]+)$")), title: gmailFolder),
            Rule(match: anyPath(), title: gmail),
        ]),
        Site(hosts: ["docs.google.com"], siteName: "Google Docs", rules: [
            Rule(match: under("/document/"), title: removing(#"\s*-\s*Google Docs$"#)),
            Rule(match: under("/spreadsheets/"), title: removing(#"\s*-\s*Google Sheets$"#)),
            Rule(match: under("/presentation/"), title: removing(#"\s*-\s*Google Slides$"#)),
            Rule(match: under("/forms/"), title: removing(#"\s*-\s*Google Forms$"#)),
        ]),
        Site(hosts: googleSearchHosts, siteName: "Google", rules: [
            Rule(match: .pathEquals("/search"), title: .queryParameter("q")),
        ]),
        Site(hosts: ["bing.com"], siteName: "Bing", rules: [Rule(match: .pathEquals("/search"), title: .queryParameter("q"))]),
        Site(hosts: ["duckduckgo.com"], siteName: "DuckDuckGo", rules: [Rule(match: .pathEquals("/"), title: .queryParameter("q"))]),
        Site(hosts: ["kagi.com"], siteName: "Kagi", rules: [Rule(match: .pathEquals("/search"), title: .queryParameter("q"))]),
        Site(hosts: ["x.com", "twitter.com"], siteName: "X", rules: [
            Rule(match: anyPath(), title: removing(#"\s*/\s*(X|Twitter)$"#)),
        ]),
        Site(hosts: ["wikipedia.org"], siteName: "Wikipedia", rules: [
            Rule(match: anyPath(), title: removing(#"\s*-\s*Wikipedia$"#)),
        ]),
        Site(hosts: ["youtube.com"], siteName: "YouTube", rules: [
            Rule(match: anyPath(), title: removing(#"\s*-\s*YouTube$"#)),
        ]),
        Site(hosts: ["github.com"], siteName: "GitHub", rules: [
            Rule(match: anyPath(), title: removing(#"^GitHub\s*-\s*"#, #"\s*[·-]\s*GitHub$"#)),
        ]),
        Site(hosts: ["linkedin.com"], siteName: "LinkedIn", rules: [
            Rule(match: anyPath(), title: removing(#"\s*\|\s*LinkedIn$"#)),
        ]),
        Site(hosts: ["reddit.com"], siteName: "Reddit", rules: [
            Rule(match: .pathEquals("/"), title: .always("Reddit")),
            Rule(match: anyPath(), title: removing(#"\s*-\s*Reddit$"#)),
        ]),
        Site(hosts: ["slack.com"], siteName: "Slack", rules: [
            Rule(match: anyPath(), title: removing(#"^[*!]\s*"#, #"\s*-\s*\d+ new items?"#, #"\s*-\s*Slack$"#)),
        ]),
        Site(hosts: ["notion.so", "notion.site"], siteName: "Notion", rules: [
            Rule(match: anyPath(), title: removing(#"\s*[|-]\s*Notion$"#)),
        ]),
        Site(hosts: ["stackoverflow.com"], siteName: "Stack Overflow", rules: [
            Rule(match: anyPath(), title: removing(#"\s*-\s*Stack Overflow$"#)),
        ]),
        Site(hosts: amazonHosts, siteName: "Amazon", rules: [
            Rule(match: anyPath(), title: removing(#"^Amazon\.[a-z.]+\s*:\s*"#, #"\s+:\s+[^:]+$"#)),
        ]),
    ]
}
