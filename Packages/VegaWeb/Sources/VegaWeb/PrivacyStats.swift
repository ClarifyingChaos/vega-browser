// Licensed under GPL-3.0. See LICENSE.
//
//  PrivacyStats.swift
//  VegaWeb
//
//  FORK: what the content blocker did, counted per site for the Privacy Report: requests blocked and connections
//  made secure. Only counts and host names, kept on this Mac; private windows are never counted.
//

import Foundation
import Observation

@MainActor @Observable
public final class PrivacyStats {
    public static let shared = PrivacyStats()

    public struct Site: Codable, Equatable, Sendable {
        public var blocked = 0
        public var upgraded = 0
        /// Blocked hosts and how often, the 20 most frequent kept.
        public var blockedHosts: [String: Int] = [:]
    }

    public private(set) var sites: [String: Site] = [:]
    public private(set) var since: Date = Date()

    private static let key = "fork.privacy.stats"
    @ObservationIgnored private var saveTask: Task<Void, Never>?

    private struct Stored: Codable { var sites: [String: Site]; var since: Date }

    private init() {
        if let data = UserDefaults.standard.data(forKey: Self.key), let stored = try? JSONDecoder().decode(Stored.self, from: data) {
            sites = stored.sites
            since = stored.since
        }
    }

    public var totalBlocked: Int { sites.values.reduce(0) { $0 + $1.blocked } }
    public var totalUpgraded: Int { sites.values.reduce(0) { $0 + $1.upgraded } }

    /// The sites that had the most blocked, most first.
    public func topSites(_ limit: Int = 50) -> [(host: String, site: Site)] {
        sites.map { ($0.key, $0.value) }.sorted { $0.1.blocked > $1.1.blocked }.prefix(limit).map { ($0.0, $0.1) }
    }

    /// Blocked hosts over every site, most first: the trackers you meet most.
    public func topBlockedHosts(_ limit: Int = 15) -> [(host: String, count: Int)] {
        var all: [String: Int] = [:]
        for site in sites.values { for (host, n) in site.blockedHosts { all[host, default: 0] += n } }
        return all.sorted { $0.value > $1.value }.prefix(limit).map { ($0.key, $0.value) }
    }

    public enum Action { case blocked, upgraded }

    func record(_ action: Action, page: String?, resource: String?) {
        guard let page = page.map(Self.site) , !page.isEmpty else { return }
        var site = sites[page] ?? Site()
        switch action {
        case .blocked:
            site.blocked += 1
            if let resource = resource.map(Self.site), !resource.isEmpty {
                site.blockedHosts[resource, default: 0] += 1
                if site.blockedHosts.count > 40 {
                    site.blockedHosts = Dictionary(uniqueKeysWithValues: site.blockedHosts.sorted { $0.value > $1.value }.prefix(20).map { ($0.key, $0.value) })
                }
            }
        case .upgraded:
            site.upgraded += 1
        }
        sites[page] = site
        // Kept small: the 400 sites with the most blocked.
        if sites.count > 500 {
            sites = Dictionary(uniqueKeysWithValues: sites.sorted { $0.value.blocked > $1.value.blocked }.prefix(400).map { ($0.key, $0.value) })
        }
        scheduleSave()
    }

    public func reset() {
        sites = [:]
        since = Date()
        save()
    }

    static func site(_ host: String) -> String {
        var h = host.lowercased()
        if h.hasPrefix("www.") { h.removeFirst(4) }
        return h
    }

    private func scheduleSave() {
        guard saveTask == nil else { return }
        saveTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(10))
            self?.save()
            self?.saveTask = nil
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(Stored(sites: sites, since: since)) { UserDefaults.standard.set(data, forKey: Self.key) }
    }
}
