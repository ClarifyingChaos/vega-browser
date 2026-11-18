// Licensed under GPL-3.0. See LICENSE.
//
//  Passwords.swift
//  Vega
//
//  FORK: Settings > Passwords: the saved logins with their icons, a page per login (show, copy and change need the
//  Mac's password or Touch ID), manual add, and import of a Chrome or Safari CSV.
//

import AppKit
import LocalAuthentication
import VegaDesign
import VegaUI
import VegaWeb
import SwiftUI
import UniformTypeIdentifiers

/// The Passwords page opens only after Touch ID or the Mac's password, every time it is opened.
struct PasswordsSettingsView: View {
    @State private var unlocked = false
    @State private var failed = false

    var body: some View {
        Group {
            if unlocked {
                PasswordsContent()
            } else {
                lockedView
            }
        }
        .onAppear { if !unlocked { unlock() } }
        // Leaving the page locks it again.
        .onDisappear { unlocked = false; failed = false }
    }

    private var lockedView: some View {
        Form {
            SettingsHero(symbol: "lock", title: "Passwords", detail: "Locked. Unlock with Touch ID or your Mac's password to see and manage saved passwords.")
            Section {
                HStack {
                    Spacer()
                    Button("Unlock", systemImage: "touchid") { unlock() }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                    Spacer()
                }
                .padding(.vertical, VegaDesign.Spacing.md)
            } footer: {
                if failed { Text("Couldn't unlock. Try again.") }
            }
        }
        .formStyle(.grouped)
    }

    private func unlock() {
        let context = LAContext()
        var error: NSError?
        // No Touch ID and no password set on the Mac: nothing to ask, so it opens.
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else { unlocked = true; return }
        context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "show your saved passwords") { ok, _ in
            Task { @MainActor in
                unlocked = ok
                failed = !ok
            }
        }
    }
}

private struct PasswordsContent: View {
    @State private var settings = PasswordSettings.shared
    @State private var logins: [SavedLogin] = []
    @State private var query = ""
    @State private var opened: SavedLogin?
    @State private var adding = false
    @State private var deleting: SavedLogin?
    @State private var importResult: String?

    @EnvironmentObject private var browserManager: BrowserManager
    /// Whose passwords are shown: the profile of the window in front, or the one picked.
    @State private var profileID: UUID?

    private var vault: PasswordVault { KeychainVault.forProfile(profileID) }

    private var shown: [SavedLogin] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        let list = q.isEmpty ? logins : logins.filter { $0.host.contains(q) || $0.username.lowercased().contains(q) }
        return list.sorted { ($0.host, $0.username.lowercased()) < ($1.host, $1.username.lowercased()) }
    }

    var body: some View {
        Form {
            SettingsHero(symbol: "key", title: "Passwords", detail: "Your saved passwords, kept in your Mac's Keychain. Click one to see, copy or change it.")

            Section {
                HStack(spacing: VegaDesign.Spacing.md) {
                    SidebarMenuSearchField(prompt: "Search passwords...", text: $query)
                    Button("Add Password", systemImage: "plus") { adding = true }
                        .labelStyle(.iconOnly)
                        .buttonStyle(.bordered)
                        .help("Add Password")
                }
                if shown.isEmpty {
                    Text(logins.isEmpty ? "No saved passwords yet. Vega offers to save one when you sign in, or add one with +." : "No passwords match \u{201C}\(query)\u{201D}.")
                        .foregroundStyle(.secondary)
                }
                ForEach(shown) { login in
                    Button { opened = login } label: { LoginRow(login: login) }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button("Copy Username", vegaIcon: "doc.on.doc") { Clipboard.copy(login.username, secret: false) }
                            Button("Copy Password", vegaIcon: "key") {
                                PasswordReveal.ask(login) { if let secret = vault.password(host: login.host, username: login.username) { Clipboard.copy(secret, secret: true) } }
                            }
                            Divider()
                            Button("Delete…", vegaIcon: "trash", role: .destructive) { deleting = login }
                        }
                }
            } header: {
                HStack {
                    Text("Saved Passwords")
                    Spacer()
                    if !logins.isEmpty { Text(logins.count.formatted()).foregroundStyle(.secondary).monospacedDigit() }
                }
            }

            Section {
                // Each profile keeps its own passwords, as in Chrome.
                if browserManager.tabs.profiles.count > 1 {
                    Picker("Profile", selection: $profileID) {
                        ForEach(browserManager.tabs.profiles) { profile in
                            Text(profile.name).tag(UUID?.some(profile.id))
                        }
                    }
                }
                Toggle("Offer to save passwords", isOn: $settings.offerToSave)
                Toggle("AutoFill passwords", isOn: $settings.autofill)
                HStack {
                    VStack(alignment: .leading, spacing: VegaDesign.Spacing.xxs) {
                        Text("Import Passwords")
                        Text(importResult ?? "From a file exported from Chrome or Safari.")
                            .font(VegaDesign.Font.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Import from CSV…") { importCSV() }
                }
            } header: {
                Text("Options")
            } footer: {
                Text("Vega asks for Touch ID or your Mac password before it fills or shows a saved password. Private windows never save or fill.")
            }

            if !settings.neverSaveHosts.isEmpty {
                Section {
                    ForEach(settings.neverSaveHosts, id: \.self) { host in
                        HStack {
                            Text(host)
                            Spacer()
                            Button("Remove") { settings.neverSaveHosts.removeAll { $0 == host } }
                        }
                    }
                } header: {
                    Text("Never Saved")
                } footer: {
                    Text("Vega won't offer to save passwords for these sites.")
                }
            }
        }
        .formStyle(.grouped)
        .onAppear {
            if profileID == nil {
                profileID = browserManager.windowRegistry?.activeWindow.flatMap { browserManager.tabs.profileID(of: $0) }
                    ?? browserManager.tabs.profiles.first?.id
            }
            reload()
        }
        .onChange(of: profileID) { reload() }
        .sheet(isPresented: $adding) { LoginEditor { save($0, $1, $2) } }
        .sheet(item: $opened) { login in
            LoginDetail(login: login, vault: vault,
                        onChange: { reload() },
                        onOpen: { url in
                            if let window = browserManager.openBrowserWindow() { browserManager.tabs.open(url: url, in: window, placement: .newTab) }
                        },
                        onDelete: { opened = nil; deleting = login })
        }
        .confirmationDialog("Delete the password for \u{201C}\(deleting?.username ?? "")\u{201D} on \(deleting?.host ?? "")?",
                            isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } })) {
            Button("Delete Password", role: .destructive) {
                if let login = deleting { vault.delete(host: login.host, username: login.username); reload() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You can't undo this.")
        }
    }

    private func reload() { logins = vault.all() }

    private func save(_ host: String, _ user: String, _ password: String) {
        let h = PasswordHosts.normalized(host.contains("://") ? (URL(string: host)?.host ?? host) : host)
        guard !h.isEmpty, !user.isEmpty, !password.isEmpty else { return }
        vault.save(host: h, username: user, password: password)
        reload()
    }

    private func importCSV() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.commaSeparatedText, .plainText]
        panel.message = "Choose a passwords file exported from Chrome or Safari."
        guard panel.runModal() == .OK, let url = panel.url, let text = try? String(contentsOf: url, encoding: .utf8) else { return }
        let result = PasswordCSV.parse(text)
        for row in result.rows { vault.save(host: row.host, username: row.username, password: row.password) }
        importResult = "Imported \(result.rows.count) \(result.rows.count == 1 ? "password" : "passwords")"
            + (result.skipped > 0 ? ", skipped \(result.skipped) without a site, user or password." : ".")
            + " You can delete the file now: it holds your passwords as plain text."
        reload()
    }
}

/// One saved login in the list: the site's icon, the site and the username.
private struct LoginRow: View {
    let login: SavedLogin

    var body: some View {
        HStack(spacing: VegaDesign.Spacing.lg) {
            SiteIcon(host: login.host, size: 28)
            VStack(alignment: .leading, spacing: VegaDesign.Spacing.xxs) {
                Text(login.host).lineLimit(1)
                Text(login.username)
                    .font(VegaDesign.Font.secondary)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(VegaDesign.Font.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, VegaDesign.Spacing.xxs)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityHint("Shows the password and its options")
    }
}

/// The site's icon from Vega's icon cache, or its first letter. Never fetches: opening this page
/// should not tell every site you have an account with that you looked.
private struct SiteIcon: View {
    let host: String
    let size: CGFloat
    @State private var image: NSImage?

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image).resizable().interpolation(.high).scaledToFit()
                    .padding(size * 0.14)
                    .background(.background, in: RoundedRectangle(cornerRadius: size * 0.24, style: .continuous))
            } else {
                Text(host.first.map { String($0).uppercased() } ?? "?")
                    .font(.system(size: size * 0.45, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.accentColor.gradient, in: RoundedRectangle(cornerRadius: size * 0.24, style: .continuous))
            }
        }
        .frame(width: size, height: size)
        .overlay(RoundedRectangle(cornerRadius: size * 0.24, style: .continuous).strokeBorder(.separator, lineWidth: 0.5))
        .accessibilityHidden(true)
        .task(id: host) {
            image = FaviconCache.shared.image(for: host)
            if image == nil { image = await FaviconCache.shared.cachedImage(for: host) }
            if image == nil, !host.hasPrefix("www.") { image = await FaviconCache.shared.cachedImage(for: "www." + host) }
        }
    }
}

/// A saved login's own page, as in Apple's Passwords: username and password with copy buttons,
/// show and hide, change the password, open the site, check it against leaks, delete.
private struct LoginDetail: View {
    let login: SavedLogin
    let vault: PasswordVault
    let onChange: () -> Void
    let onOpen: (URL) -> Void
    let onDelete: () -> Void
    @Environment(\.dismiss) private var dismiss

    /// The password, once Touch ID allowed it. Nil means it is still hidden.
    @State private var secret: String?
    @State private var shown = false
    @State private var editing = false
    @State private var draft = ""
    @State private var breach: String?
    @State private var copied: String?

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: VegaDesign.Spacing.lg) {
                SiteIcon(host: login.host, size: 44)
                VStack(alignment: .leading, spacing: VegaDesign.Spacing.xxs) {
                    Text(login.host).font(VegaDesign.Font.titleLarge).lineLimit(1)
                    Text("Changed \(login.modified.formatted(date: .abbreviated, time: .omitted))")
                        .font(VegaDesign.Font.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding([.horizontal, .top], VegaDesign.Spacing.xxxl)

            Form {
                Section {
                    LabeledContent("Username") {
                        HStack(spacing: VegaDesign.Spacing.md) {
                            Text(login.username).textSelection(.enabled).lineLimit(1)
                            copyButton("Username") { copy(login.username, secret: false, what: "Username") }
                        }
                    }
                    LabeledContent("Password") {
                        HStack(spacing: VegaDesign.Spacing.md) {
                            if editing {
                                TextField("Password", text: $draft)
                                    .labelsHidden()
                                    .font(VegaDesign.Font.mono)
                                    .frame(minWidth: 180)
                            } else if shown, let secret {
                                Text(secret).font(VegaDesign.Font.mono).textSelection(.enabled).lineLimit(1)
                            } else {
                                Text(String(repeating: "\u{2022}", count: 10)).foregroundStyle(.secondary)
                                    .accessibilityLabel("Hidden")
                            }
                            if !editing {
                                Button(shown ? "Hide Password" : "Show Password", systemImage: shown ? "eye.slash" : "eye") {
                                    if shown { shown = false } else { unlock { _ in shown = true } }
                                }
                                .labelStyle(.iconOnly).buttonStyle(.borderless)
                                .help(shown ? "Hide Password" : "Show Password")
                                copyButton("Password") { unlock { copy($0, secret: true, what: "Password") } }
                            }
                        }
                    }
                    LabeledContent("Website") {
                        Button(login.host) { openSite() }
                            .buttonStyle(.link)
                            .help("Open \(login.host) in a new tab")
                    }
                } footer: {
                    if let copied { Text("\(copied) copied. A copied password leaves the clipboard after 60 seconds.") }
                }

                Section {
                    HStack {
                        VStack(alignment: .leading, spacing: VegaDesign.Spacing.xxs) {
                            Text("Check if Leaked")
                            Text(breach ?? "Only the first 5 characters of the password's hash leave your Mac.")
                                .font(VegaDesign.Font.caption)
                                .foregroundStyle(breach?.hasPrefix("Found") == true ? .red : .secondary)
                        }
                        Spacer()
                        Button("Check") { unlock { check($0) } }
                    }
                }
            }
            .formStyle(.grouped)
            .scrollDisabled(true)

            HStack {
                Button("Delete…", role: .destructive) { onDelete() }
                Spacer()
                if editing {
                    Button("Cancel", role: .cancel) { editing = false }
                    Button("Save") { saveDraft() }
                        .keyboardShortcut(.defaultAction)
                        .disabled(draft.isEmpty)
                } else {
                    Button("Change Password…") { unlock { draft = $0; editing = true } }
                    Button("Done") { dismiss() }.keyboardShortcut(.defaultAction)
                }
            }
            .padding(.horizontal, VegaDesign.Spacing.xxxl)
            .padding(.bottom, VegaDesign.Spacing.xxl)
        }
        .frame(width: 480)
    }

    private func copyButton(_ what: String, action: @escaping () -> Void) -> some View {
        Button("Copy \(what)", systemImage: "doc.on.doc", action: action)
            .labelStyle(.iconOnly).buttonStyle(.borderless)
            .help("Copy \(what)")
    }

    /// Touch ID once per sheet: the password is kept only while the sheet is open.
    private func unlock(_ use: @escaping (String) -> Void) {
        if let secret { use(secret); return }
        PasswordReveal.ask(login) {
            guard let value = vault.password(host: login.host, username: login.username) else { return }
            secret = value
            use(value)
        }
    }

    private func copy(_ text: String, secret: Bool, what: String) {
        Clipboard.copy(text, secret: secret)
        copied = what
    }

    private func saveDraft() {
        vault.save(host: login.host, username: login.username, password: draft)
        secret = draft
        editing = false
        onChange()
    }

    private func check(_ password: String) {
        breach = "Checking\u{2026}"
        Task {
            breach = switch await PasswordBreach.timesSeen(password) {
            case nil: "Could not reach the breach service. Nothing was sent that identifies you."
            case 0: "Not found in known leaks."
            case let n?: "Found in known leaks \(n.formatted()) times. Change this password."
            }
        }
    }

    private func openSite() {
        guard let url = URL(string: "https://\(login.host)") else { return }
        onOpen(url)
        dismiss()
    }
}

/// Touch ID or the Mac's password before a saved password is shown or copied.
private enum PasswordReveal {
    @MainActor static func ask(_ login: SavedLogin, then use: @escaping @MainActor () -> Void) {
        let context = LAContext()
        context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "show your saved password for \u{201C}\(login.host)\u{201D}") { ok, _ in
            guard ok else { return }
            Task { @MainActor in use() }
        }
    }
}

private enum Clipboard {
    @MainActor static func copy(_ text: String, secret: Bool) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        guard secret else { return }
        // A copied password does not stay on the clipboard.
        let count = NSPasteboard.general.changeCount
        DispatchQueue.main.asyncAfter(deadline: .now() + 60) {
            if NSPasteboard.general.changeCount == count { NSPasteboard.general.clearContents() }
        }
    }
}

/// A new login: site, username and password.
private struct LoginEditor: View {
    @State private var host = ""
    @State private var username = ""
    @State private var password = ""
    let save: (String, String, String) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            Form {
                TextField("Website", text: $host, prompt: Text("example.com"))
                TextField("Username", text: $username)
                SecureField("Password", text: $password)
            }
            .formStyle(.grouped)
            .scrollDisabled(true)
            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                Button("Add") { save(host, username, password); dismiss() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(host.isEmpty || username.isEmpty || password.isEmpty)
            }
            .padding(VegaDesign.Spacing.xl)
        }
        .frame(width: 420)
    }
}
