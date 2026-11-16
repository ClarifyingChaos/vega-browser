// Licensed under GPL-3.0. See LICENSE.
//
//  PasswordGate.swift
//  NookWeb
//
//  FORK: a saved password is handed to a page only after the person proves it is them, with Touch ID or
//  the Mac's password, as Apple's Passwords does. One proof covers the same site for a short while, so a
//  sign-in that fills a username and then a password asks once, not twice.
//

import Foundation
import LocalAuthentication

@MainActor
public final class PasswordGate {
    public static let shared = PasswordGate()

    /// How long one proof covers the same site.
    public static let grace: TimeInterval = 60

    /// Asks the person. Replaceable so a check can answer without a Touch ID sensor.
    public var authenticate: (_ host: String) async -> Bool = { host in
        let context = LAContext()
        var error: NSError?
        // No Touch ID and no password on the Mac: nothing to ask, as in Settings › Passwords.
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else { return true }
        return (try? await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "AutoFill your password for \(host)")) ?? false
    }

    private var provedAt: [String: Date] = [:]
    private var asking: [String: Task<Bool, Never>] = [:]
    var now: () -> Date = Date.init

    public init() {}

    /// True when the person may fill a saved password on this site now.
    public func allows(host: String) async -> Bool {
        let site = PasswordHosts.normalized(host)
        if let at = provedAt[site], now().timeIntervalSince(at) < Self.grace { return true }
        // Two fills arriving together share one prompt.
        if let running = asking[site] { return await running.value }
        let task = Task { await authenticate(site) }
        asking[site] = task
        let ok = await task.value
        asking[site] = nil
        if ok { provedAt[site] = now() }
        return ok
    }

    /// Forget every proof, e.g. when the Mac locks.
    public func reset() { provedAt = [:] }
}
