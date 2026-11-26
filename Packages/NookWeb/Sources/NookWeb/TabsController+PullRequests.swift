// Licensed under GPL-3.0. See LICENSE.
//
//  TabsController+PullRequests.swift
//  Nook
//

import Foundation
import NookTabsCore

extension TabsController {
    /// The open pull requests of a space's github.com login, for a favorite's hover card. Empty
    /// when signed out or when the list could not be read.
    public func pullRequests(inSpace spaceID: UUID) async -> [LivePage] {
        guard let profile = profile(forSpace: spaceID) else { return [] }
        let cookies = await profile.dataStore.httpCookieStore.allCookies()
        return (try? await GitHubPulls.fetch(cookies: cookies)) ?? []
    }
}
