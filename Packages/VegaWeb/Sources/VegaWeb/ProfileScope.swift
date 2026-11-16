// Licensed under GPL-3.0. See LICENSE.
//
//  ProfileScope.swift
//  VegaWeb
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

    /// "" for the first profile (or an unknown one), ".<id>" for the others.
    public static func suffix(for profileID: UUID?) -> String {
        guard let profileID, let primary = primaryID, primary != profileID else { return "" }
        return ".\(profileID.uuidString)"
    }

    public static func isPrimary(_ profileID: UUID?) -> Bool { suffix(for: profileID).isEmpty }
}
