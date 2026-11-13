// Licensed under GPL-3.0. See LICENSE.
//
//  SavePasswordBar.swift
//  Vega
//
//  FORK: "Save password?" above the sidebar's media controls, like the Cast bar. Shown on the tab
//  where the login happened until the person answers, or after two minutes.
//

import VegaDesign
import VegaUI
import VegaWeb
import SwiftUI

struct SavePasswordBar: View {
    @Environment(BrowserWindowState.self) private var windowState
    @State private var prompter = PasswordPrompter.shared

    var body: some View {
        if let pending = prompter.pending, pending.itemID == windowState.selectedItemID {
            VStack(alignment: .leading, spacing: VegaDesign.Spacing.md) {
                HStack(spacing: VegaDesign.Spacing.md) {
                    Image(systemName: "key.fill")
                        .foregroundStyle(.white)
                    VStack(alignment: .leading, spacing: 0) {
                        Text(pending.isUpdate ? "Update password?" : "Save password?")
                            .font(VegaDesign.Font.title)
                            .foregroundStyle(.white)
                        Text(pending.username.isEmpty ? pending.host : "\(pending.username) on \(pending.host)")
                            .font(VegaDesign.Font.secondary)
                            .foregroundStyle(.white.opacity(0.7))
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    Spacer(minLength: 0)
                }
                HStack(spacing: VegaDesign.Spacing.sm) {
                    Button("Never") { prompter.neverSavePending() }
                    Button("Not Now") { prompter.dismiss() }
                    Spacer(minLength: 0)
                    Button(pending.isUpdate ? "Update" : "Save") { prompter.savePending() }
                        .keyboardShortcut(.defaultAction)
                        .buttonStyle(.borderedProminent)
                }
                .controlSize(.small)
            }
            .padding(10)
            .background(VegaDesign.Radius.shape(VegaDesign.Radius.md).fill(Color.black))
            .overlay(VegaDesign.Radius.shape(VegaDesign.Radius.md).stroke(Color.white.opacity(0.2), lineWidth: 0.5))
            .padding(.horizontal, VegaDesign.Spacing.sidebarInset)
            .transition(.opacity.combined(with: .move(edge: .bottom)))
            .accessibilityElement(children: .contain)
        }
    }
}
