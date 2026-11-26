// Licensed under GPL-3.0. See LICENSE.
//
//  SitePermission.swift
//  Nook
//
//  Created by Bain Gurley on 21/09/2026.
//

import Foundation

/// A capability a page can ask for and Nook can answer without prompting.
///
/// Only camera and microphone are here. WebKit routes those through
/// `requestMediaCaptureAuthorization`, so a stored answer can be applied. Geolocation and web
/// notifications have no per-origin delegate on macOS, so there is nothing to store an answer
/// for; those stay app-level and the menu says so rather than implying otherwise.
public enum SitePermission: String, Codable, CaseIterable, Sendable {
    case camera
    case microphone
}

/// What to do when a site asks. `.ask` means prompt, which is WebKit's own behaviour.
public enum SitePermissionPolicy: String, Codable, CaseIterable, Sendable {
    case ask
    case allow
    case block

    public var label: String {
        switch self {
        case .ask: return "Ask"
        case .allow: return "Allow"
        case .block: return "Block"
        }
    }
}

/// Safari's three Auto-Play choices for a site. `.allowAll` is what a site with no choice gets.
public enum SiteAutoplay: String, Codable, CaseIterable, Sendable {
    case allowAll
    case stopMediaWithSound
    case never

    public var label: String {
        switch self {
        case .allowAll: return "Allow All Auto-Play"
        case .stopMediaWithSound: return "Stop Media with Sound"
        case .never: return "Never Auto-Play"
        }
    }
}

/// One site's stored answers, keyed by host. Hosts are stored lowercased with `www.` dropped so
/// `www.example.com` and `example.com` share one decision.
public struct SitePermissionRecord: Codable, Equatable, Sendable {
    public var host: String
    public var policies: [SitePermission: SitePermissionPolicy]
    /// 1.8.x saved this and the next field here, where nothing read them. `SitePreferences.adopt` moves them out.
    public var autoplay: SiteAutoplay?
    public var autoPictureInPicture: Bool?

    public init(host: String, policies: [SitePermission: SitePermissionPolicy] = [:]) {
        self.host = host
        self.policies = policies
    }

    public var isEmpty: Bool { policies.isEmpty && autoplay == nil && autoPictureInPicture == nil }

    /// The canonical key for a host, so one site has one record.
    public static func key(for host: String) -> String {
        let lower = host.lowercased()
        return lower.hasPrefix("www.") ? String(lower.dropFirst(4)) : lower
    }
}

extension Dictionary where Key == String, Value == SitePermissionRecord {
    /// Changes one site's record, and drops it once it holds nothing so the store does not grow forever.
    public mutating func update(_ host: String, _ change: (inout SitePermissionRecord) -> Void) {
        let key = SitePermissionRecord.key(for: host)
        var record = self[key] ?? SitePermissionRecord(host: key)
        change(&record)
        self[key] = record.isEmpty ? nil : record
    }
}
