// Licensed under GPL-3.0. See LICENSE.
// swiftc Packages/NookWeb/Sources/NookWeb/Passwords/KeychainIsolation.swift Packages/NookWeb/Checks/KeychainIsolationCheck.swift -o /tmp/ki && /tmp/ki
//
// FORK: only the shipping app reaches the real Keychain items; any other build gets its own.

@main
struct KeychainIsolationCheck {
    static func main() {
        let ship = KeychainIsolation.shippingPrefix
        precondition(KeychainIsolation.prefix(testPrefix: nil, bundleID: ship) == ship)
        precondition(KeychainIsolation.prefix(testPrefix: nil, bundleID: nil) == ship)
        precondition(KeychainIsolation.prefix(testPrefix: nil, bundleID: "com.vega.uitest") == "com.vega.uitest.kc", "a test copy without the setting stays apart")
        precondition(KeychainIsolation.prefix(testPrefix: "", bundleID: "com.vega.uitest") == "com.vega.uitest.kc")
        precondition(KeychainIsolation.prefix(testPrefix: "t.kc", bundleID: ship) == "t.kc")
        precondition(KeychainIsolation.service("com.nook.aiProvider", prefix: ship) == "com.nook.aiProvider", "the shipping app keeps its items")
        precondition(KeychainIsolation.service("com.nook.aiProvider", prefix: "com.vega.uitest.kc") == "com.vega.uitest.kc.com.nook.aiProvider")
        print("KeychainIsolationCheck passed")
    }
}
