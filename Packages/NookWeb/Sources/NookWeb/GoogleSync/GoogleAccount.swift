// Licensed under GPL-3.0. See LICENSE.
//
//  GoogleAccount.swift
//  NookWeb
//
//  FORK: who is signed in to Google for sync. The refresh token lives in this Mac's Keychain; the
//  short-lived access token only in memory.
//

import AppKit
import Foundation
import Observation
import Security

@MainActor @Observable
public final class GoogleAccount {
    /// The first profile's account.
    public static let shared = GoogleAccount(profileID: nil)

    // FORK: each profile signs in to its own Google account, as in Chrome.
    private static var others: [UUID: GoogleAccount] = [:]
    public static func forProfile(_ profileID: UUID?) -> GoogleAccount {
        guard let profileID, !ProfileScope.isPrimary(profileID) else { return shared }
        if let existing = others[profileID] { return existing }
        let account = GoogleAccount(profileID: profileID)
        others[profileID] = account
        return account
    }

    /// Where a sign-in waits until we know which profile it is for (an account added from another Mac).
    public static let pending = GoogleAccount(suffix: ".pending")

    private let suffix: String
    private var emailKey: String { "fork.google.email" + suffix }
    private var service: String { "com.vega.browser.google" + suffix }

    private init(profileID: UUID?) {
        suffix = ProfileScope.suffix(for: profileID)
        email = UserDefaults.standard.string(forKey: "fork.google.email" + suffix)
    }

    private init(suffix: String) {
        self.suffix = suffix
        email = UserDefaults.standard.string(forKey: "fork.google.email" + suffix)
    }

    /// Hands this sign-in to a profile: its account from now on. This one is signed out.
    public func move(to profileID: UUID) {
        guard let refresh = loadRefreshToken(), let email else { return }
        let target = Self.forProfile(profileID)
        target.adopt(refresh: refresh, email: email)
        signOut()
    }

    private func adopt(refresh: String, email: String) {
        saveRefreshToken(refresh)
        access = nil
        self.email = email
        UserDefaults.standard.set(email, forKey: emailKey)
    }

    public private(set) var email: String?
    public private(set) var isSigningIn = false
    public var isSignedIn: Bool { email != nil && loadRefreshToken() != nil }
    /// False in a build without a Google client: the sign-in button says so instead of failing.
    public var isAvailable: Bool { GoogleOAuthConfig.load() != nil }

    @ObservationIgnored private var access: GoogleOAuth.Tokens?
    @ObservationIgnored private var loopback: GoogleLoopback?

    public func signIn() async throws {
        guard let config = GoogleOAuthConfig.load() else { throw GoogleOAuth.OAuthError.notConfigured }
        isSigningIn = true
        defer { isSigningIn = false; loopback = nil }
        let state = UUID().uuidString
        let pkce = GoogleOAuth.PKCE()
        let server = try GoogleLoopback(state: state)
        loopback = server
        let port = try await server.start()
        NSWorkspace.shared.open(GoogleOAuth.authorizationURL(config: config, port: port, state: state, pkce: pkce))
        let code = try await server.code()
        let tokens = try await GoogleOAuth.exchange(code: code, config: config, port: port, verifier: pkce.verifier)
        guard let refresh = tokens.refresh else { throw GoogleOAuth.OAuthError.badResponse }
        saveRefreshToken(refresh)
        access = tokens
        email = tokens.email
        UserDefaults.standard.set(tokens.email, forKey: emailKey)
    }

    public func cancelSignIn() { loopback?.cancel() }

    public func signOut() {
        deleteRefreshToken()
        access = nil
        email = nil
        UserDefaults.standard.removeObject(forKey: emailKey)
    }

    /// A store for the sync code, or nil when nobody is signed in.
    public func store() -> GoogleDriveStore? {
        guard isSignedIn else { return nil }
        return GoogleDriveStore(token: { [weak self] in try await self?.accessToken() ?? { throw GoogleOAuth.OAuthError.cancelled }() })
    }

    /// A store on Vega's own sync server at `url`, signed in with this Google account.
    public func serverStore(url: URL) -> ServerBlobStore? {
        guard isSignedIn else { return nil }
        return ServerBlobStore(base: url, token: { [weak self] in try await self?.idToken() ?? { throw GoogleOAuth.OAuthError.cancelled }() })
    }

    /// The Google ID token, refreshed with the access token (both last an hour).
    public func idToken() async throws -> String {
        if let access, access.expires > Date(), let id = access.idToken { return id }
        guard let config = GoogleOAuthConfig.load(), let refresh = loadRefreshToken() else { throw GoogleOAuth.OAuthError.notConfigured }
        let fresh = try await GoogleOAuth.refresh(refresh, config: config)
        access = fresh
        guard let id = fresh.idToken else { throw GoogleOAuth.OAuthError.badResponse }
        return id
    }

    private func accessToken() async throws -> String {
        if let access, access.expires > Date() { return access.access }
        guard let config = GoogleOAuthConfig.load(), let refresh = loadRefreshToken() else { throw GoogleOAuth.OAuthError.notConfigured }
        let fresh = try await GoogleOAuth.refresh(refresh, config: config)
        access = fresh
        return fresh.access
    }

    private func loadRefreshToken() -> String? {
        let q: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service,
                                kSecReturnData as String: true, kSecMatchLimit as String: kSecMatchLimitOne]
        var r: CFTypeRef?
        guard SecItemCopyMatching(q as CFDictionary, &r) == errSecSuccess, let d = r as? Data else { return nil }
        return String(data: d, encoding: .utf8)
    }
    private func saveRefreshToken(_ token: String) {
        deleteRefreshToken()
        SecItemAdd([kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service,
                    kSecValueData as String: Data(token.utf8), kSecAttrLabel as String: "Vega Google Account"] as CFDictionary, nil)
    }
    private func deleteRefreshToken() {
        SecItemDelete([kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service] as CFDictionary)
    }
}
