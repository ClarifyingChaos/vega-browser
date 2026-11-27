// Licensed under GPL-3.0. See LICENSE.
//
//  PageSession+BlockedPopup.swift
//  NookWeb
//
//  The window the pop-up guard last refused on this page, and what can be done with it.
//

import Foundation
import NookSettings

extension PageSession {
    /// Web addresses only, and only while this site's pop-ups are blocked.
    func noteBlockedPopup(_ address: String) {
        guard blocksPopups, address.count < 8_000, let url = URL(string: address),
              ["http", "https"].contains(url.scheme?.lowercased()), url.host != nil else { return }
        blockedPopup = url
    }

    /// Opens the refused address once, in a new tab. The site stays blocked.
    public func openBlockedPopup() {
        guard let url = blockedPopup, let controller, let window = controller.window(for: self),
              let id = controller.open(url: url, in: window, placement: .newTab, from: itemID) else { return }
        // A tab that only receives a download closes itself, as a tab the page opened would.
        controller.session(for: id)?.openedByPage = true
        blockedPopup = nil
    }

    /// The page showing learns the new choice at once; later pages are told as they load.
    public func popupChoiceChanged() {
        if !blocksPopups { blockedPopup = nil }
        primaryWebView?.evaluateJavaScript("window.__vegaAllowPopups = \(!blocksPopups)", completionHandler: nil)
    }
}
