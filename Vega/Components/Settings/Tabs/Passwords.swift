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
    /// Logins only an older Vega's Keychain items hold: they can't sync until imported again.
    @State private var waiting: [SavedLogin] = []
    @State private var showsWaiting = false
    @State private var audit: PasswordAudit?
    @State private var auditing = false

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

            if !waiting.isEmpty {
                Section {
                    Label {
                        VStack(alignment: .leading, spacing: VegaDesign.Spacing.xs) {
                            Text("\(waiting.count) of \(logins.count) passwords stay on this Mac").font(VegaDesign.Font.label)
                            Text("They were saved by an older Vega, and macOS asks before Vega may read each one, so sync leaves them out. Bring them in once from a passwords file and they sync to your other Macs.")
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                    }
                    VStack(alignment: .leading, spacing: VegaDesign.Spacing.xs) {
                        Text("1. Export your passwords from where you saved them:")
                        Text("    Chrome: Settings › Passwords and autofill › Google Password Manager › Settings › Export")
                        Text("    Safari or the Passwords app: File › Export All Passwords…")
                        Text("2. Choose Import from CSV… below and pick the file.")
                        Text("3. Delete the file: it holds your passwords as plain text.")
                    }
                    .font(VegaDesign.Font.secondary)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                    HStack {
                        Button(showsWaiting ? "Hide List" : "Show Which Ones") { showsWaiting.toggle() }
                        Spacer()
                        Button("Import from CSV…") { importCSV() }.buttonStyle(.borderedProminent)
                    }
                    if showsWaiting {
                        ForEach(waiting) { login in
                            HStack {
                                Text(login.host).lineLimit(1)
                                Spacer()
                                Text(login.username).foregroundStyle(.secondary).lineLimit(1)
                            }
                            .font(VegaDesign.Font.secondary)
                        }
                    }
                } header: {
                    Text("Not Synced")
                }
            }

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
                HStack {
                    VStack(alignment: .leading, spacing: VegaDesign.Spacing.xxs) {
                        Text("Security Check")
                        Text(auditSummary).font(VegaDesign.Font.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    if auditing { ProgressView().controlSize(.small) }
                    else { Button(audit == nil ? "Check Passwords…" : "Check Again") { runAudit() }.disabled(logins.isEmpty) }
                }
                if let audit {
                    ForEach(audit.leaked) { finding(row: $0, symbol: "exclamationmark.octagon.fill", tint: .red) }
                    ForEach(audit.reused) { finding(row: $0, symbol: "arrow.triangle.2.circlepath", tint: .orange) }
                    ForEach(audit.weak) { finding(row: $0, symbol: "exclamationmark.triangle.fill", tint: .yellow) }
                }
            } footer: {
                Text("Finds passwords seen in known leaks, used on more than one site, or easy to guess. For the leak check only the first 5 characters of each password's hash leave your Mac. Logins saved by an older Vega are checked once imported.")
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

    private var auditSummary: String {
        guard let audit else { return "Check every saved password at once." }
        if audit.leaked.isEmpty && audit.reused.isEmpty && audit.weak.isEmpty {
            return "\(audit.checked) passwords checked: nothing to fix." + (audit.unreachable ? " The leak service couldn't be reached." : "")
        }
        return "\(audit.checked) checked · \(audit.leaked.count) leaked · \(audit.reused.count) reused · \(audit.weak.count) weak"
            + (audit.unreachable ? " · leak service unreachable" : "")
    }

    private func finding(row: PasswordAudit.Finding, symbol: String, tint: Color) -> some View {
        Button {
            if let login = logins.first(where: { $0.id == row.id }) { opened = login }
        } label: {
            HStack(spacing: VegaDesign.Spacing.lg) {
                Image(systemName: symbol).foregroundStyle(tint).frame(width: 20)
                VStack(alignment: .leading, spacing: 0) {
                    Text(row.host).lineLimit(1)
                    Text("\(row.username) · \(row.detail)").font(VegaDesign.Font.caption).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer()
                Image(systemName: "chevron.right").font(VegaDesign.Font.caption).foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// Reads every readable password once (after Touch ID), off the main thread, and checks them.
    private func runAudit() {
        PasswordReveal.ask(reason: "check your saved passwords") {
            auditing = true
            nonisolated(unsafe) let vault = self.vault
            Task {
                let pairs: [(login: SavedLogin, password: String)] = await Task.detached(priority: .userInitiated) {
                    vault.readable().compactMap { l in vault.quietly { vault.password(host: l.host, username: l.username) }.map { (l, $0) } }
                }.value
                var result = PasswordAudit()
                result.checked = pairs.count
                let groups = Dictionary(grouping: pairs, by: \.password)
                for (_, users) in groups where users.count > 1 {
                    for user in users {
                        result.reused.append(.init(id: user.login.id, host: user.login.host, username: user.login.username,
                                                   detail: "Same password on \(users.count - 1) other \(users.count == 2 ? "site" : "sites")"))
                    }
                }
                for pair in pairs {
                    if let why = PasswordAudit.weakness(pair.password) {
                        result.weak.append(.init(id: pair.login.id, host: pair.login.host, username: pair.login.username, detail: why))
                    }
                }
                for (password, users) in groups {
                    guard let seen = await PasswordBreach.timesSeen(password) else { result.unreachable = true; continue }
                    guard seen > 0 else { continue }
                    for user in users {
                        result.leaked.append(.init(id: user.login.id, host: user.login.host, username: user.login.username,
                                                   detail: "Seen \(seen.formatted()) times in known leaks"))
                    }
                }
                audit = result
                auditing = false
            }
        }
    }

    private func reload() {
        logins = vault.all()
        waiting = vault.legacyOnly().sorted { $0.host < $1.host }
    }

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
    /// The verification-code generator, read after Touch ID; `hasCode` is known without reading it.
    @State private var code: TOTP?
    @State private var hasCode = false
    @State private var settingUpCode = false
    @State private var now = Date()
    private let tick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

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
                    LabeledContent("Verification Code") {
                        HStack(spacing: VegaDesign.Spacing.md) {
                            if let code {
                                let value = code.code(at: now)
                                Text(value.count == 6 ? "\(value.prefix(3)) \(value.suffix(3))" : value)
                                    .font(VegaDesign.Font.mono).monospacedDigit().textSelection(.enabled)
                                Text("\(code.secondsLeft(at: now))s").font(VegaDesign.Font.caption).foregroundStyle(.secondary).monospacedDigit()
                                copyButton("Code") { copy(value, secret: true, what: "Code") }
                                Menu {
                                    Button("Remove Verification Code", role: .destructive) {
                                        vault.setTOTP(nil, host: login.host, username: login.username)
                                        self.code = nil
                                        hasCode = false
                                    }
                                } label: { Image(systemName: "ellipsis.circle") }
                                .menuStyle(.button).buttonStyle(.borderless).menuIndicator(.hidden).fixedSize()
                                .accessibilityLabel("More for the verification code")
                            } else if hasCode {
                                Button("Show Code") { unlock { _ in code = vault.totp(host: login.host, username: login.username) } }
                            } else {
                                Button("Set Up…") { unlock { _ in settingUpCode = true } }
                            }
                        }
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
        .onAppear { hasCode = vault.hasTOTP(host: login.host, username: login.username) }
        .onReceive(tick) { now = $0 }
        .sheet(isPresented: $settingUpCode) {
            CodeSetupSheet { totp in
                vault.setTOTP(totp, host: login.host, username: login.username)
                code = totp
                hasCode = true
            }
        }
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
/// Pasting the setup key (or otpauth:// link) a site shows when you turn on two-factor sign-in.
private struct CodeSetupSheet: View {
    let save: (TOTP) -> Void
    @State private var text = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let parsed = TOTP(text)
        VStack(alignment: .leading, spacing: VegaDesign.Spacing.lg) {
            Text("Set Up Verification Code").font(VegaDesign.Font.heading)
            Text("On the site, turn on two-factor sign-in with an authenticator app. Choose to enter a setup key instead of scanning the code, and paste the key or link here.")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            TextField("Setup key or otpauth:// link", text: $text)
                .textFieldStyle(.roundedBorder)
                .font(VegaDesign.Font.mono)
            if let parsed {
                Text("Current code: \(parsed.code())  ·  type it on the site to finish").font(VegaDesign.Font.secondary).foregroundStyle(.secondary)
            } else if !text.isEmpty {
                Text("That doesn't look like a setup key.").font(VegaDesign.Font.secondary).foregroundStyle(.red)
            }
            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                Button("Save") { if let parsed { save(parsed); dismiss() } }
                    .keyboardShortcut(.defaultAction)
                    .disabled(parsed == nil)
            }
        }
        .padding(VegaDesign.Spacing.xxl)
        .frame(width: 440)
    }
}

/// Every readable password checked at once: found in known leaks, used on more than one site, or weak.
struct PasswordAudit: Sendable {
    struct Finding: Identifiable, Sendable {
        let id: String
        let host: String
        let username: String
        let detail: String
    }
    var leaked: [Finding] = []
    var reused: [Finding] = []
    var weak: [Finding] = []
    var checked = 0
    var unreachable = false

    static func weakness(_ password: String) -> String? {
        if password.count < 8 { return "Shorter than 8 characters" }
        if password.allSatisfy(\.isNumber) { return "Only numbers" }
        if Set(password).count <= 3 { return "Repeats a few characters" }
        let lower = password.lowercased()
        for common in ["password", "123456", "qwerty", "letmein", "welcome", "iloveyou", "admin"] where lower.contains(common) {
            return "Contains \u{201C}\(common)\u{201D}"
        }
        return nil
    }
}

private enum PasswordReveal {
    @MainActor static func ask(_ login: SavedLogin, then use: @escaping @MainActor () -> Void) {
        ask(reason: "show your saved password for \u{201C}\(login.host)\u{201D}", then: use)
    }

    @MainActor static func ask(reason: String, then use: @escaping @MainActor () -> Void) {
        let context = LAContext()
        context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { ok, _ in
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
