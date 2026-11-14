// Licensed under GPL-3.0. See LICENSE.
//
//  SharedSpaceCheck.swift
//  Vega
//
//  The .vegaspace format: a space round-trips through JSON, nested folders count their pages, and a file
//  from a newer format is refused. Compiles the shipped source:
//
//    swiftc Packages/VegaWeb/Sources/VegaWeb/SharedSpace.swift Packages/VegaWeb/Checks/SharedSpaceCheck.swift -o /tmp/shared-space-check && /tmp/shared-space-check
//

import Foundation

@main
struct SharedSpaceCheck {
    static func main() throws {
        let space = SharedSpace(name: "Research", icon: "book", accentHex: "7A5CFF",
                                favorites: [.init(title: "Apple", url: "https://apple.com")],
                                pinned: [.init(title: "Reading", children: [.init(title: "Swift", url: "https://swift.org"), .init(title: "Deep", children: [.init(title: "Vega", url: "https://example.com")])])],
                                tabs: [.init(title: "Docs", url: "https://developer.apple.com")])
        precondition(space.tabCount == 4, "folders count their pages, not themselves: \(space.tabCount)")
        let data = try JSONEncoder().encode(space)
        let back = try JSONDecoder().decode(SharedSpace.self, from: data)
        precondition(back == space, "a space survives a round trip")
        precondition(back.pinned[0].children[1].children[0].url == "https://example.com", "nesting survives")
        precondition(SharedSpace.limit == 600, "a file can bring in at most 600 items")
        let newer = String(data: data, encoding: .utf8)!.replacingOccurrences(of: "\"format\":1", with: "\"format\":99")
        let decoded = try JSONDecoder().decode(SharedSpace.self, from: Data(newer.utf8))
        precondition(decoded.format > SharedSpace.formatVersion, "a newer format is visible as newer, so the importer can refuse it")
        print("SharedSpace ok: round trip, nesting and format version")
    }
}
