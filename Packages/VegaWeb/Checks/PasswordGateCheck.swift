// Licensed under GPL-3.0. See LICENSE.
//
//  PasswordGateCheck.swift
//  Vega
//
//  A saved password is filled only after the person proves it is them: a refusal fills nothing, one proof
//  covers the same site for a minute and never another site, and two fills at once ask once.
//
//    swiftc -parse-as-library Packages/VegaTabsCore/Sources/VegaTabsCore/*.swift Packages/VegaWeb/Sources/VegaWeb/Passwords/PasswordGate.swift \
//           Packages/VegaWeb/Sources/VegaWeb/Passwords/PasswordLogic.swift Packages/VegaWeb/Sources/VegaWeb/Passwords/PublicSuffix.swift Packages/VegaWeb/Sources/VegaWeb/Passwords/TOTP.swift Packages/VegaWeb/Sources/VegaWeb/Passwords/PasswordSync.swift \
//           Packages/VegaWeb/Checks/PasswordGateCheck.swift -o /tmp/password-gate-check && /tmp/password-gate-check

import Foundation

@main
struct PasswordGateCheck {
    @MainActor static func main() async {
        let gate = PasswordGate()
        var asked: [String] = []
        var answer = false
        gate.authenticate = { host in asked.append(host); try? await Task.sleep(for: .milliseconds(30)); return answer }

        var ok = await gate.allows(host: "www.example.com")
        precondition(!ok, "a refused proof fills nothing")
        ok = await gate.allows(host: "example.com")
        precondition(!ok && asked.count == 2, "a refusal is not remembered")

        answer = true
        ok = await gate.allows(host: "example.com")
        precondition(ok, "a proof fills")
        ok = await gate.allows(host: "www.example.com")
        precondition(ok, "the same site, www or not, is covered")
        precondition(asked.count == 3, "the second fill did not ask again: \(asked)")
        ok = await gate.allows(host: "other.com")
        precondition(ok && asked.count == 4 && asked.last == "other.com", "another site proves again, by name")

        var clock = Date()
        gate.now = { clock }
        gate.reset()
        ok = await gate.allows(host: "example.com")
        clock = clock.addingTimeInterval(PasswordGate.grace + 1)
        let before = asked.count
        ok = await gate.allows(host: "example.com")
        precondition(ok && asked.count == before + 1, "the cover runs out")

        gate.reset()
        let n = asked.count
        async let first = gate.allows(host: "twice.com")
        async let second = gate.allows(host: "twice.com")
        let both = await (first, second)
        precondition(both.0 && both.1 && asked.count == n + 1, "two fills at once ask once")
        print("PasswordGateCheck ok")
    }
}
