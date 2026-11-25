// Licensed under GPL-3.0. See LICENSE.
//
//  VegaURLCommandCheck.swift
//  Vega
//
//  swiftc Packages/VegaWeb/Sources/VegaWeb/VegaURLCommand.swift \
//         Packages/VegaWeb/Checks/VegaURLCommandCheck.swift -o /tmp/vegaurl-check && /tmp/vegaurl-check
//

import Foundation

@main
struct VegaURLCommandCheck {
    static func parse(_ s: String) -> VegaURLCommand? { VegaURLCommand.parse(URL(string: s)!) }

    static func main() {
        let open = parse("vega://open?url=https%3A%2F%2Fexample.com%2Fa%3Fb%3D1%23x&space=Work&reuse=1&junk=2")
        precondition(open?.action == .open(URL(string: "https://example.com/a?b=1#x")!, reuse: true))
        precondition(open?.space == "Work" && open?.ignored == ["junk"])
        precondition(parse("vega://open?url=http://a.com")?.action == .open(URL(string: "http://a.com")!, reuse: false))
        precondition(parse("VEGA://OPEN?url=https://a.com") != nil)
        precondition(parse("nook://open?url=https://a.com") == nil, "the upstream project's scheme is not Vega's")
        precondition(parse("vega://search?q=hello%20world&space=a")?.action == .search("hello world"))
        precondition(parse("vega://space?name=Work")?.space == "Work")
        precondition(parse("vega://open?url=https://a.com&space=") == nil && parse("vega://open?url=https://a.com&space=%20") == nil)
        precondition(parse("vega://search?q=a&space=" + String(repeating: "x", count: 9000)) == nil)

        // Hostile or malformed
        for bad in [
            "vega://open", "vega://open?url=", "vega://open?url=file:///etc/passwd",
            "vega://open?url=javascript:alert(1)", "vega://open?url=data:text/html,hi",
            "vega://open?url=vega://open?url=https://a.com", "vega://open?url=https://",
            "vega://open?url=ftp://a.com", "vega://search", "vega://search?q=%20", "vega://space",
            "vega://quit", "vega://delete?url=https://a.com", "vega:///open?url=https://a.com",
            "https://open?url=https://a.com", "vega://open?url=" + String(repeating: "a", count: 9000),
        ] {
            precondition(parse(bad) == nil, bad)
        }
        // First duplicate wins; reuse only for exactly 1.
        precondition(parse("vega://open?url=https://a.com&url=file:///x")?.action == .open(URL(string: "https://a.com")!, reuse: false))
        precondition(parse("vega://open?url=https://a.com&reuse=true")?.action == .open(URL(string: "https://a.com")!, reuse: false))

        // Search URL
        let t = "https://www.google.com/search?q=%@"
        precondition(VegaURLCommand.searchURL(for: "a&b c+d", template: t)?.absoluteString == "https://www.google.com/search?q=a%26b%20c%2Bd")
        precondition(VegaURLCommand.searchURL(for: "x", template: "javascript:%@") == nil)

        // Space match
        let a = UUID(), b = UUID()
        let spaces = [(id: a, name: "Work"), (id: b, name: "Home")]
        precondition(VegaURLCommand.match("work", in: spaces) == a)
        precondition(VegaURLCommand.match(b.uuidString.lowercased(), in: spaces) == b)
        precondition(VegaURLCommand.match("Wor", in: spaces) == nil)
        precondition(VegaURLCommand.match(UUID().uuidString, in: spaces) == nil)

        // Same page
        func same(_ x: String, _ y: String) -> Bool { VegaURLCommand.isSamePage(URL(string: x)!, URL(string: y)!) }
        precondition(same("https://A.com/p/#top", "https://a.com/p"))
        precondition(same("https://a.com", "https://a.com/"))
        precondition(!same("https://a.com/p?x=1", "https://a.com/p?x=2"))
        precondition(!same("http://a.com", "https://a.com"))
        print("VegaURLCommandCheck passed")
    }
}
