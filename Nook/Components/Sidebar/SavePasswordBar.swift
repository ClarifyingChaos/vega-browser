// Licensed under GPL-3.0. See LICENSE.
//
//  SavePasswordBar.swift
//  Nook
//
//  FORK: "Save password?" above the sidebar's media controls, like the Cast bar. Shown on the tab
//  where the login happened until the person answers, or after two minutes.
//

import NookDesign
import NookUI
import NookWeb
import SwiftUI

struct SavePasswordBar: View {
    @Environment(BrowserWindowState.self) private var windowState
    @State private var prompter = PasswordPrompter.shared

    var body: some View {
        if let pending = prompter.pending, pending.itemID == windowState.selectedItemID {
            VStack(alignment: .leading, spacing: 14) {
                // What is being asked.
                HStack(alignment: .center, spacing: 10) {
                    Image(systemName: "key.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 32, height: 32)
                        .background(Color.accentColor.gradient, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                        .accessibilityHidden(true)
                    Text(pending.isUpdate ? "Update Password?" : "Save Password?")
                        .font(NookDesign.Font.title)
                        .foregroundStyle(.white)
                    Spacer(minLength: 0)
                }

                // What it is about: the site and the user name, so it can be told at a glance.
                VStack(alignment: .leading, spacing: 2) {
                    Text(pending.host)
                        .font(NookDesign.Font.label)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Text(pending.username.isEmpty ? (pending.isUpdate ? "Replaces the saved password" : "No user name") : pending.username)
                        .font(NookDesign.Font.secondary)
                        .foregroundStyle(.white.opacity(0.78))
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color.white.opacity(0.09), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

                // What can be done: the main answer first and widest, the other two quieter.
                VStack(spacing: 8) {
                    Button { prompter.savePending() } label: {
                        Text(pending.isUpdate ? "Update Password" : "Save Password")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)

                    Button("Not Now") { prompter.dismiss() }
                        .buttonStyle(OnDarkSecondaryButtonStyle())

                    if !pending.isUpdate {
                        Button("Never for This Website") { prompter.neverSavePending() }
                            .buttonStyle(.plain)
                            .font(NookDesign.Font.secondary)
                            .foregroundStyle(.white.opacity(0.78))
                            .frame(maxWidth: .infinity)
                            .padding(.top, 2)
                    }
                }
                .controlSize(.large)
            }
            .padding(14)
            .background(NookDesign.Radius.shape(NookDesign.Radius.lg).fill(Color.black))
            .overlay(NookDesign.Radius.shape(NookDesign.Radius.lg).stroke(Color.white.opacity(0.18), lineWidth: 0.5))
            .padding(.horizontal, NookDesign.Spacing.sidebarInset)
            .transition(.opacity.combined(with: .move(edge: .bottom)))
            .accessibilityElement(children: .contain)
        }
    }
}

/// A second button on the prompt's black card: a light, clearly visible fill that matches the primary button's shape,
/// since the system "bordered" look is dark grey on black and hardly reads as a button there.
private struct OnDarkSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 28)
            .padding(.vertical, 2)
            .background(Capsule().fill(Color.white.opacity(configuration.isPressed ? 0.28 : 0.15)))
            .contentShape(Capsule())
    }
}
