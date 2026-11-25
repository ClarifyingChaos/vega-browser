// Licensed under GPL-3.0. See LICENSE.
//
//  KeepSignedIn.swift
//  NookSettings
//
//  FORK: which website data stays when Vega clears data at quit. WebKit groups data by site (the registrable
//  domain, "google.com"), so keeping mail.google.com keeps google.com's cookies: a sign-in lives there.
//

import Foundation

public enum KeepSignedIn {
    /// A typed site as stored: host only, lowercased, no scheme, path, port or `www.`. Nil when it is not a host.
    public static func normalize(_ typed: String) -> String? {
        var text = typed.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !text.contains("://") { text = "https://" + text }
        guard let host = URL(string: text)?.host, host.contains("."), !host.hasPrefix("."), !host.hasSuffix(".") else { return nil }
        return host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
    }

    /// Whether a data record named `recordName` (WebKit's display name, a registrable domain) belongs to a kept site.
    public static func keeps(_ recordName: String, sites: [String]) -> Bool {
        let record = recordName.lowercased()
        return sites.contains { site in site == record || site.hasSuffix("." + record) || record.hasSuffix("." + site) }
    }
}
