// Licensed under GPL-3.0. See LICENSE.
//
//  ProfileScopeCheck.swift
//  Nook
//
//  The first profile keeps the names every earlier version used; any other profile gets its own, so two profiles never
//  share a Google sign-in, sync passphrase or passwords. Compiles the shipped source:
//
//    swiftc Packages/NookWeb/Sources/NookWeb/ProfileScope.swift Packages/NookWeb/Checks/ProfileScopeCheck.swift -o /tmp/profile-scope-check && /tmp/profile-scope-check

import Foundation

@main
struct ProfileScopeCheck {
    static func main() {
        let defaults = UserDefaults.standard
        let saved = defaults.string(forKey: ProfileScope.primaryKey)
        defer { saved.map { defaults.set($0, forKey: ProfileScope.primaryKey) } ?? defaults.removeObject(forKey: ProfileScope.primaryKey) }

        let first = UUID(), second = UUID()
        defaults.removeObject(forKey: ProfileScope.primaryKey)
        precondition(ProfileScope.suffix(for: first).isEmpty && ProfileScope.suffix(for: nil).isEmpty, "with no first profile yet, nothing is renamed")

        defaults.set(first.uuidString, forKey: ProfileScope.primaryKey)
        precondition(ProfileScope.suffix(for: first).isEmpty && ProfileScope.isPrimary(first), "the first profile keeps its old names")
        precondition(ProfileScope.suffix(for: nil).isEmpty, "an unknown profile reads as the first")
        precondition(ProfileScope.suffix(for: second) == ".\(second.uuidString)" && !ProfileScope.isPrimary(second), "another profile gets its own")
        precondition(ProfileScope.suffix(for: second) != ProfileScope.suffix(for: UUID()), "and no two profiles share one")

        // A fresh Mac that takes the account's profile as its first one: the names move to it, the old first loses them.
        let adopted = UUID()
        ProfileScope.setPrimary(adopted)
        precondition(ProfileScope.suffix(for: adopted).isEmpty && ProfileScope.suffix(for: first) == ".\(first.uuidString)", "the account's profile is now the first")

        // The profile file another Mac reads: it round-trips, and junk or nothing reads as no profile.
        let identity = ProfileIdentity(id: adopted, name: "Bosch")
        precondition(ProfileIdentity.decode(identity.encoded()) == identity, "profile.json round trips")
        precondition(ProfileIdentity.decode(nil) == nil && ProfileIdentity.decode(Data("not json".utf8)) == nil, "no file or a bad one is no profile")
        print("ProfileScopeCheck ok")
    }
}
