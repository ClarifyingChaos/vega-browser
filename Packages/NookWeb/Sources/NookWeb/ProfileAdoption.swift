// Licensed under GPL-3.0. See LICENSE.
//
//  ProfileAdoption.swift
//  NookWeb
//
//  FORK: bringing a profile onto this Mac by signing in to its Google account, as in Chrome. The account's folder says
//  which profile it holds (`profile.json`); this Mac makes that same profile, signs it in, and turns its sync on, and
//  its spaces arrive on the next sync.
//

import Foundation
import NookTabsCore

@MainActor
public enum ProfileAdoption {
    public enum Outcome: Equatable {
        /// The account's profile was brought here.
        case brought(profileID: UUID, name: String)
        /// The account had no profile yet: a new one now uses it.
        case created(profileID: UUID)
        /// This Mac already has that profile; the account is now its account.
        case alreadyHere(profileID: UUID)
    }

    /// Signs in to a Google account and makes it a profile of this Mac: the account's own when it has one, else a new
    /// profile called `name`.
    public static func addFromGoogle(tabs: TabsController, name: String) async throws -> Outcome {
        let pending = GoogleAccount.pending
        try await pending.signIn()
        guard let store = pending.store() else { throw GoogleOAuth.OAuthError.cancelled }
        let remote = ProfileIdentity.decodePublic(try? await store.get(ProfileIdentity.path))
        let outcome: Outcome
        let profileID: UUID
        if let remote {
            profileID = remote.id
            if tabs.profiles.contains(where: { $0.id == remote.id }) {
                outcome = .alreadyHere(profileID: remote.id)
            } else {
                guard let space = tabs.createSpace(name: remote.name, icon: "", accentHex: tabs.orderedSpaces.last?.accentHex ?? "#0A84FF",
                                                   after: tabs.orderedSpaces.last?.id, profileName: remote.name, dataStoreID: remote.id) else {
                    pending.signOut()
                    throw GoogleOAuth.OAuthError.badResponse
                }
                UserDefaults.standard.set(space.uuidString, forKey: SyncCoordinator.placeholderKey(remote.id))
                outcome = .brought(profileID: remote.id, name: remote.name)
            }
        } else {
            guard let space = tabs.createSpace(name: name, icon: "", accentHex: tabs.orderedSpaces.last?.accentHex ?? "#0A84FF",
                                               after: tabs.orderedSpaces.last?.id, profileName: name),
                  let id = tabs.profiles.first(where: { $0.spaceIDs.contains(space) })?.id else {
                pending.signOut()
                throw GoogleOAuth.OAuthError.badResponse
            }
            profileID = id
            outcome = .created(profileID: id)
        }
        pending.move(to: profileID)
        let sync = SyncCoordinator.forProfile(profileID)
        sync.backend = .google
        sync.isEnabled = true
        return outcome
    }

    /// A profile nobody has set up yet: nothing favorited or pinned, and only the tab or two a new install opens. A
    /// profile with a person's own favorites or pinned tabs is never swapped for another.
    static func isFresh(_ profile: ProfileSummary, in tabs: TabsController) -> Bool {
        profile.spaceIDs.allSatisfy { space in
            tabs.favorites(of: space).isEmpty && tabs.children(of: .pinned(spaceID: space)).isEmpty && tabs.tabCount(inSpace: space) <= 3
        }
    }

    /// A fresh Mac that signs in as its first profile (Google or iCloud Drive, whichever sync is set to): when the place
    /// holds a profile and this Mac has nothing yet of its own, take that profile as the first one, so the Mac doesn't
    /// end up with two. Returns true when it did.
    @discardableResult
    public static func reconcileFirstProfile(tabs: TabsController) async -> Bool {
        guard tabs.profiles.count == 1, let local = tabs.profiles.first, isFresh(local, in: tabs),
              let remote = await SyncCoordinator.shared.remoteProfile(),
              remote.id != local.id else { return false }
        guard let space = tabs.createSpace(name: remote.name, icon: "", accentHex: tabs.orderedSpaces.last?.accentHex ?? "#0A84FF",
                                           after: tabs.orderedSpaces.last?.id, profileName: remote.name, dataStoreID: remote.id) else { return false }
        UserDefaults.standard.set(space.uuidString, forKey: SyncCoordinator.placeholderKey(remote.id))
        // Nothing was saved under the old first profile, so the names it held move to the account's profile.
        ProfileScope.setPrimary(remote.id)
        for old in local.spaceIDs { tabs.deleteSpace(old) }
        SyncCoordinator.shared.syncNow()
        return true
    }
}
