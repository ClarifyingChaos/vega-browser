// Licensed under GPL-3.0. See LICENSE.
//
//  AccountStage.swift
//  Nook
//
//  FORK: the first-run sign-in step. Signing in with Google turns sync on, so spaces, favorites and open tabs
//  follow the person to their other Macs; password sync is one switch further. Skippable: Settings › General ›
//  Account has the same sign-in later.
//

import NookDesign
import NookUI
import NookWeb
import SwiftUI

struct AccountStage: View {
    /// Label on the left, switch on the right edge, so the switches line up.
    private func row(_ title: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) { Text(title).frame(maxWidth: .infinity, alignment: .leading) }
    }

    @EnvironmentObject private var browserManager: BrowserManager
    @State private var google = GoogleAccount.shared
    @State private var sync = SyncCoordinator.shared
    @State private var error: String?
    @State private var askingPassphrase = false

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: google.isSignedIn ? "checkmark.circle.fill" : "person.crop.circle")
                .font(.system(size: 56))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.white)
                .contentTransition(.symbolEffect(.replace))
            Text(google.isSignedIn ? "You're Signed In" : "Sign In to Vega")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.white)
            Text(google.isSignedIn
                 ? (google.email ?? "")
                 : "Keep your spaces, favorites, open tabs and passwords the same on all your Macs.")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white.opacity(0.75))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 380)

            if google.isSignedIn {
                VStack(alignment: .leading, spacing: 12) {
                    row("Sync spaces, favorites and pinned tabs", isOn: Binding(get: { sync.isEnabled }, set: { sync.isEnabled = $0 }))
                    row("Keep my open tabs the same on my Macs", isOn: Binding(get: { sync.mirrorsTabs }, set: { sync.mirrorsTabs = $0 }))
                        .disabled(!sync.isEnabled)
                    row("Sync passwords", isOn: Binding(
                        get: { sync.passwordsEnabled },
                        set: { on in
                            if on { Task { if await !sync.resumePasswords() { askingPassphrase = true } } }
                            else { sync.disablePasswords() }
                        }))
                        .disabled(!sync.isEnabled)
                }
                .toggleStyle(.switch)
                .foregroundStyle(.white)
                .padding(16)
                .frame(width: 380)
                .background(.white.opacity(0.08), in: NookDesign.Radius.shape(NookDesign.Radius.lg))
            } else if google.isSigningIn {
                HStack(spacing: 10) {
                    ProgressView().controlSize(.small)
                    Text("Finish signing in in your browser\u{2026}").foregroundStyle(.white.opacity(0.8))
                    Button("Cancel") { google.cancelSignIn() }
                }
            } else {
                VStack(spacing: 10) {
                    Button {
                        error = nil
                        Task {
                            do {
                                try await google.signIn()
                                // A new Mac signing in as its first profile takes the account's profile, not a second one.
                                await ProfileAdoption.reconcileFirstProfile(tabs: browserManager.tabs)
                                sync.backend = .google
                                // Everything is shared by default: other Macs list this one's open tabs too.
                                sync.sharesOpenTabs = true
                                sync.isEnabled = true
                            } catch { self.error = error.localizedDescription }
                        }
                    } label: {
                        Text("Sign in with Google")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.black)
                            .padding(.vertical, 10)
                            .padding(.horizontal, 22)
                            .background(.white, in: NookDesign.Radius.shape(NookDesign.Radius.lg))
                    }
                    .buttonStyle(.plain)
                    .disabled(!google.isAvailable)
                    Button("Use iCloud Drive instead") {
                        sync.backend = .iCloud
                        sync.isEnabled = true
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))
                    if sync.isEnabled && sync.backend == .iCloud {
                        Text("Syncing through iCloud Drive.").font(.system(size: 12)).foregroundStyle(.white.opacity(0.6))
                    }
                }
            }
            if let error {
                Text(error).font(.system(size: 12)).foregroundStyle(.red)
            }
        }
        .sheet(isPresented: $askingPassphrase) { SyncPassphraseSheet(sync: sync, changing: false).environment(\.colorScheme, .dark) }
    }
}
