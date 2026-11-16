// Licensed under GPL-3.0. See LICENSE.
//
//  ProfileScope.swift
//  NookWeb
//
//  FORK: which names belong to which profile. The first profile (the one that existed before profiles had their own
//  accounts and passwords) keeps every name it always had; any other profile adds `.<profile id>`, so nothing a
//  person already set up moves.
//

import Foundation

public enum ProfileScope {
    /// Set once by `KeychainVault.claimPrimary`: the profile that keeps the original names.
    static let primaryKey = "fork.passwords.primaryProfile"

    public static var primaryID: UUID? {
        UserDefaults.standard.string(forKey: primaryKey).flatMap(UUID.init(uuidString:))
    }

    /// Makes `profileID` the first profile. Only when nothing was saved under the old one (a fresh install).
    public static func setPrimary(_ profileID: UUID) {
        UserDefaults.standard.set(profileID.uuidString, forKey: primaryKey)
    }

    /// "" for the first profile (or an unknown one), ".<id>" for the others.
    public static func suffix(for profileID: UUID?) -> String {
        guard let profileID, let primary = primaryID, primary != profileID else { return "" }
        return ".\(profileID.uuidString)"
    }

    public static func isPrimary(_ profileID: UUID?) -> Bool { suffix(for: profileID).isEmpty }
}

/// `profile.json` in a profile's sync folder: who the profile is, so another Mac that signs in to the same account
/// can bring the same profile instead of making a new one.
public struct ProfileIdentity: Codable, Equatable, Sendable {
    public var id: UUID
    public var name: String

    public static let path = "profile.json"

    public init(id: UUID, name: String) {
        self.id = id
        self.name = name
    }

    public func encoded() -> Data { (try? JSONEncoder().encode(self)) ?? Data() }
    public static func decode(_ data: Data?) -> ProfileIdentity? {
        data.flatMap { try? JSONDecoder().decode(ProfileIdentity.self, from: $0) }
    }
}
