// Licensed under GPL-3.0. See LICENSE.
//
//  ProfileScopeCheck.swift
//  Vega
//
//  The first profile keeps the names every earlier version used; any other profile gets its own, so two profiles never
//  share a Google sign-in, sync passphrase or passwords. Compiles the shipped source:
//
//    swiftc Packages/VegaWeb/Sources/VegaWeb/ProfileScope.swift Packages/VegaWeb/Checks/ProfileScopeCheck.swift -o /tmp/profile-scope-check && /tmp/profile-scope-check

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
        print("ProfileScopeCheck ok")
    }
}
