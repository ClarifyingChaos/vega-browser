// Licensed under GPL-3.0. See LICENSE.
//
//  KeychainIsolation.swift
//  NookWeb
//
//  FORK: which Keychain items a build may touch. Only the shipping app uses the real ones; a test copy under another
//  bundle id gets its own, even when nobody set `fork.keychain.testPrefix` for it.
//

import Foundation

public enum KeychainIsolation {
    public static let shippingPrefix = "com.vega.browser"

    /// The prefix for this build's items: the test prefix when set, the shipping one for the shipping app, otherwise
    /// one of the build's own.
    public static func prefix(testPrefix: String?, bundleID: String?) -> String {
        if let testPrefix, !testPrefix.isEmpty { return testPrefix }
        let id = bundleID ?? shippingPrefix
        return id == shippingPrefix ? shippingPrefix : id + ".kc"
    }

    /// `service` as the shipping app names it, or this build's own copy of it.
    public static func service(_ service: String, prefix: String) -> String {
        prefix == shippingPrefix ? service : prefix + "." + service
    }
}
