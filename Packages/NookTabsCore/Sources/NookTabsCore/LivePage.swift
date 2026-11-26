// Licensed under GPL-3.0. See LICENSE.
import Foundation

/// One page a site reports, for a favorite's hover card.
public struct LivePage: Hashable, Sendable {
    public var url: URL
    public var title: String

    public init(url: URL, title: String) {
        self.url = url
        self.title = title
    }
}

