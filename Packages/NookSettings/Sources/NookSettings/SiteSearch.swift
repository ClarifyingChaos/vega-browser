// Licensed under GPL-3.0. See LICENSE.
//
//  SiteSearch.swift
//  Nook
//
//  Site search (Tab-to-Search) data model and matching logic
//

import Foundation

// MARK: - Custom Search Engine

public struct CustomSearchEngine: Codable, Identifiable, Equatable, Sendable {
    public var id: UUID
    public var name: String
    public var urlTemplate: String   // uses %@ placeholder like SearchProvider.queryTemplate

    public init(id: UUID = UUID(), name: String, urlTemplate: String) {
        self.id = id
        self.name = name
        self.urlTemplate = urlTemplate
    }

    public enum TemplateError: String, Error {
        case notHTTPS = "Only https:// addresses are allowed, so searches stay encrypted."
        case noPlaceholder = "Add %s where the search words go."
        case invalid = "That is not a valid address."
    }

    /// The stored spelling (`%@`) of a typed search address. Search words must travel encrypted.
    public static func template(from input: String) -> Result<String, TemplateError> {
        let typed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard typed.lowercased().hasPrefix("https://") else { return .failure(.notHTTPS) }
        let template = typed.replacingOccurrences(of: "%s", with: "%@")
        guard template.contains("%@") else { return .failure(.noPlaceholder) }
        let sample = template.replacingOccurrences(of: "%@", with: "x")
        // The words may not choose the site: a placeholder in the host would send each search somewhere else.
        guard !typed.contains(where: \.isWhitespace), let url = URLComponents(string: sample), let host = url.host, !host.isEmpty,
              url.user == nil, URLComponents(string: template.replacingOccurrences(of: "%@", with: "y"))?.host == host
        else { return .failure(.invalid) }
        return .success(template)
    }

    /// One-click choices offered in the Add Search Engine sheet.
    public static let popular: [(name: String, template: String)] = [
        ("Startpage", "https://www.startpage.com/sp/search?query=%s"),
        ("Qwant", "https://www.qwant.com/?q=%s"),
        ("Mojeek", "https://www.mojeek.com/search?q=%s"),
        ("Swisscows", "https://swisscows.com/en/web?query=%s"),
        ("Wikipedia", "https://en.wikipedia.org/w/index.php?search=%s"),
        ("YouTube", "https://www.youtube.com/results?search_query=%s"),
        ("GitHub", "https://github.com/search?q=%s"),
    ]
}

// MARK: - Site Search Entry

public struct SiteSearchEntry: Codable, Identifiable, Equatable {
    public var id: UUID
    public var name: String
    public var domain: String
    public var searchURLTemplate: String
    public var colorHex: String

    public init(id: UUID = UUID(), name: String, domain: String, searchURLTemplate: String, colorHex: String) {
        self.id = id
        self.name = name
        self.domain = domain
        self.searchURLTemplate = searchURLTemplate
        self.colorHex = colorHex
    }

    public func searchURL(for query: String) -> URL? {
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            return nil
        }
        var template = searchURLTemplate
        if !template.hasPrefix("http://") && !template.hasPrefix("https://") {
            template = "https://" + template
        }
        let urlString = template.replacingOccurrences(of: "{query}", with: encoded)
        return URL(string: urlString)
    }

    public func matches(prefix: String) -> Bool {
        let lower = prefix.lowercased()
        return name.lowercased().hasPrefix(lower) || domain.lowercased().hasPrefix(lower)
    }

    // MARK: - Defaults

    public static let defaultSites: [SiteSearchEntry] = [
        SiteSearchEntry(
            name: "YouTube", domain: "youtube.com",
            searchURLTemplate: "https://www.youtube.com/results?search_query={query}",
            colorHex: "#E62617"
        ),
        SiteSearchEntry(
            name: "GitHub", domain: "github.com",
            searchURLTemplate: "https://github.com/search?q={query}",
            colorHex: "#8B4DD9"
        ),
        SiteSearchEntry(
            name: "Reddit", domain: "reddit.com",
            searchURLTemplate: "https://www.reddit.com/search/?q={query}",
            colorHex: "#FF7300"
        ),
        SiteSearchEntry(
            name: "X", domain: "x.com",
            searchURLTemplate: "https://x.com/search?q={query}",
            colorHex: "#666666"
        ),
        SiteSearchEntry(
            name: "Wikipedia", domain: "wikipedia.org",
            searchURLTemplate: "https://en.wikipedia.org/w/index.php?search={query}",
            colorHex: "#737373"
        ),
        SiteSearchEntry(
            name: "Amazon", domain: "amazon.com",
            searchURLTemplate: "https://www.amazon.com/s?k={query}",
            colorHex: "#FF8C00"
        ),
        SiteSearchEntry(
            name: "Twitch", domain: "twitch.tv",
            searchURLTemplate: "https://www.twitch.tv/search?term={query}",
            colorHex: "#9146EB"
        ),
        SiteSearchEntry(
            name: "Spotify", domain: "open.spotify.com",
            searchURLTemplate: "https://open.spotify.com/search/{query}",
            colorHex: "#1DB954"
        ),
        SiteSearchEntry(
            name: "Stack Overflow", domain: "stackoverflow.com",
            searchURLTemplate: "https://stackoverflow.com/search?q={query}",
            colorHex: "#F28C0D"
        ),
        SiteSearchEntry(
            name: "Perplexity", domain: "perplexity.ai",
            searchURLTemplate: "https://www.perplexity.ai/search?q={query}",
            colorHex: "#20B8CD"
        ),
        SiteSearchEntry(
            name: "ChatGPT", domain: "chatgpt.com",
            searchURLTemplate: "https://chatgpt.com/?q={query}",
            colorHex: "#10A37F"
        ),
        SiteSearchEntry(
            name: "Claude", domain: "claude.ai",
            searchURLTemplate: "https://claude.ai/new?q={query}",
            colorHex: "#D97757"
        ),
        SiteSearchEntry(
            name: "Gemini", domain: "gemini.google.com",
            searchURLTemplate: "https://gemini.google.com/app?q={query}",
            colorHex: "#8E75B2"
        ),
        SiteSearchEntry(
            name: "Grok", domain: "grok.com",
            searchURLTemplate: "https://grok.com/?q={query}",
            colorHex: "#000000"
        ),
    ]

    public static func match(for text: String, in sites: [SiteSearchEntry]) -> SiteSearchEntry? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return sites.first { $0.matches(prefix: trimmed) }
    }
}

