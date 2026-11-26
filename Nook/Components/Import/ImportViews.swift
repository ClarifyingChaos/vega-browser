// Licensed under GPL-3.0. See LICENSE.
//
//  ImportViews.swift
//  Nook
//
//  FORK: the import screens, shared by the menu's dialog and the first launch: the browser picker,
//  what to bring from Chrome, its passwords file, and the finished card.
//

import AppKit
import NookDesign
import NookUI
import NookWeb
import SwiftUI

enum ImportSource: String, CaseIterable, Identifiable {
    case chrome, safari, arc, dia

    var id: Self { self }

    var name: String {
        switch self {
        case .chrome: "Chrome"
        case .safari: "Safari"
        case .arc: "Arc"
        case .dia: "Dia"
        }
    }

    private var bundleID: String {
        switch self {
        case .chrome: "com.google.Chrome"
        case .safari: "com.apple.Safari"
        case .arc: "company.thebrowser.Browser"
        case .dia: "company.thebrowser.dia"
        }
    }

    /// The browser's own icon, from the copy on this Mac.
    var appIcon: NSImage? {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID).map { NSWorkspace.shared.icon(forFile: $0.path) }
    }

    /// True when there is something to import: its data is here, or for Safari, which exports a folder, always.
    var isAvailable: Bool {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let file: String
        switch self {
        case .chrome: file = "Google/Chrome/Local State"
        case .safari: return true
        case .arc: file = "Arc/StorableSidebar.json"
        case .dia: file = "Dia/StorableProfileContainers.json"
        }
        return FileManager.default.fileExists(atPath: support.appendingPathComponent(file).path)
    }

    static var firstAvailable: ImportSource { allCases.first(where: \.isAvailable) ?? .safari }
}

// MARK: - Pieces

private struct BrowserIcon: View {
    let source: ImportSource
    let size: CGFloat

    var body: some View {
        Group {
            if let image = source.appIcon {
                Image(nsImage: image).resizable().scaledToFit()
            } else {
                NookSymbol("globe", size: size * 0.7)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

struct BrowserPicker: View {
    @Binding var selection: ImportSource

    var body: some View {
        HStack(spacing: NookDesign.Spacing.md) {
            ForEach(ImportSource.allCases) { source in
                let available = source.isAvailable
                let chosen = selection == source
                Button { selection = source } label: {
                    VStack(spacing: NookDesign.Spacing.md) {
                        BrowserIcon(source: source, size: 48)
                        Text(source.name).font(NookDesign.Font.body)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, NookDesign.Spacing.xl)
                    .padding(.bottom, NookDesign.Spacing.lg)
                    .background(NookDesign.Radius.shape(NookDesign.Radius.lg).fill(chosen ? NookDesign.Surface.fillPressed : NookDesign.Surface.fill))
                    .overlay(NookDesign.Radius.shape(NookDesign.Radius.lg).strokeBorder(chosen ? Color.primary : .clear, lineWidth: 1.5))
                    .overlay(alignment: .topTrailing) {
                        if chosen {
                            Image(systemName: "checkmark.circle.fill").padding(NookDesign.Spacing.sm).accessibilityHidden(true)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(!available)
                .opacity(available ? 1 : 0.4)
                .help(available ? "" : "\(source.name) has nothing to import on this Mac")
                .accessibilityAddTraits(chosen ? .isSelected : [])
            }
        }
    }
}

private struct ImportHeader<Mark: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder let mark: Mark

    var body: some View {
        HStack(spacing: NookDesign.Spacing.xl) {
            mark
                .frame(width: 44, height: 44)
                .background(NookDesign.Radius.shape(NookDesign.Radius.lg).fill(NookDesign.Surface.fillPressed))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: NookDesign.Spacing.xs) {
                Text(title).font(NookDesign.Font.heading)
                Text(subtitle).font(NookDesign.Font.secondary).foregroundStyle(.secondary)
            }
        }
    }
}

private struct ImportGroup<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 0) { content }
            .background(NookDesign.Radius.shape(NookDesign.Radius.lg).fill(NookDesign.Surface.fill))
    }
}

private struct ImportRow<Trailing: View>: View {
    var symbol: String? = nil
    let title: String
    var detail: String? = nil
    @ViewBuilder let trailing: Trailing

    var body: some View {
        HStack(spacing: NookDesign.Spacing.lg) {
            if let symbol { NookSymbol(symbol, size: 18).frame(width: 20).accessibilityHidden(true) }
            VStack(alignment: .leading, spacing: NookDesign.Spacing.xxs) {
                Text(title).font(NookDesign.Font.body)
                if let detail {
                    Text(detail).font(NookDesign.Font.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: NookDesign.Spacing.md)
            trailing
        }
        .padding(NookDesign.Spacing.lg)
    }
}

private struct ImportSwitch: View {
    var symbol: String? = nil
    let title: String
    let detail: String
    @Binding var isOn: Bool

    var body: some View {
        ImportRow(symbol: symbol, title: title, detail: detail) {
            Toggle(title, isOn: $isOn).toggleStyle(.switch).labelsHidden().controlSize(.small).tint(.gray)
        }
    }
}

private struct ImportButton: View {
    let title: String
    var primary = false
    var key: SwiftUI.KeyboardShortcut? = nil
    let action: () -> Void

    var body: some View {
        Button(title, action: action)
            .buttonStyle(DialogButtonStyle(variant: primary ? .primary : .secondary))
            .keyboardShortcut(key)
    }
}

/// Scrolls an import screen only when the window is too short to hold it.
struct ImportScroll<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        ViewThatFits(in: .vertical) {
            content
            ScrollView { content }
        }
    }
}

// MARK: - Chrome

/// What to bring over from Chrome, with the passwords file as a step of its own.
struct ChromeImportPanel: View {
    @EnvironmentObject private var browserManager: BrowserManager
    let onBack: () -> Void
    /// The sentence saying what came in, and the extensions to offer.
    let onImported: (String, [ExtensionChoice]) -> Void

    @State private var profiles: [ChromeProfile] = []
    @State private var profileID = "Default"
    @State private var bookmarks = true
    @State private var history = true
    @State private var extensions = true
    @State private var showingPasswords = false
    @State private var trashFile = true
    @State private var passwordResult: String?
    @State private var working = false

    private var profile: ChromeProfile? { profiles.first { $0.id == profileID } }

    var body: some View {
        VStack(alignment: .leading, spacing: NookDesign.Spacing.xl) {
            if showingPasswords { passwords } else { options }
        }
        .onAppear {
            profiles = browserManager.importManager.chromeProfiles()
            profileID = profiles.first?.id ?? profileID
        }
    }

    @ViewBuilder private var options: some View {
        ImportHeader(title: "Import from Chrome", subtitle: "Turn off anything you would rather leave behind.") {
            BrowserIcon(source: .chrome, size: 30)
        }
        if profiles.count > 1 {
            ImportGroup {
                ImportRow(title: "Chrome profile") {
                    Picker("Chrome profile", selection: $profileID) {
                        ForEach(profiles) { Text($0.name).tag($0.id) }
                    }
                    .labelsHidden()
                    .fixedSize()
                }
            }
        }
        ImportGroup {
            ImportSwitch(symbol: "folder", title: "Bookmarks", detail: "Into a new space named \u{201C}Chrome\u{201D}, folders kept", isOn: $bookmarks)
            Divider()
            ImportSwitch(symbol: "clock", title: "Browsing history", detail: "Last 90 days", isOn: $history)
            Divider()
            ImportSwitch(symbol: "puzzlepiece.extension", title: "Extensions", detail: "You review each one before it installs", isOn: $extensions)
            Divider()
            ImportRow(symbol: "key", title: "Passwords", detail: "Through a file you export from Chrome") {
                ImportButton(title: "Show Steps") { showingPasswords = true }
            }
        }
        HStack(spacing: NookDesign.Spacing.md) {
            NookSymbol("shield.lefthalf.filled", size: 16).accessibilityHidden(true)
            Text("Vega never reads Chrome\u{2019}s cookies, saved passwords or cards.")
        }
        .font(NookDesign.Font.caption)
        .foregroundStyle(.secondary)
        HStack {
            ImportButton(title: "Back", key: .cancelAction, action: onBack)
            Spacer()
            if working { ProgressView().controlSize(.small) }
            ImportButton(title: working ? "Importing\u{2026}" : "Import", primary: true, key: .defaultAction, action: run)
                .disabled(working || profile == nil || !(bookmarks || history || extensions))
        }
    }

    @ViewBuilder private var passwords: some View {
        ImportHeader(title: "Bring your passwords", subtitle: "Three steps, nothing leaves this Mac.") {
            NookSymbol("key", size: 22)
        }
        ImportGroup {
            step(1, "In Chrome, open **Google Password Manager \u{203A} Settings**.")
            Divider()
            step(2, "Choose **Download file** and save it.")
            Divider()
            step(3, "Choose that file here.")
        }
        ImportGroup {
            ImportSwitch(title: "Move the file to the Trash afterwards",
                         detail: "It holds your passwords as plain text. Empty the Trash to remove it.", isOn: $trashFile)
        }
        if let passwordResult {
            Text(passwordResult).font(NookDesign.Font.secondary).fixedSize(horizontal: false, vertical: true)
        }
        HStack {
            ImportButton(title: "Back", key: .cancelAction) { showingPasswords = false }
            Spacer()
            ImportButton(title: "Choose File\u{2026}", primary: true, key: .defaultAction) {
                if let result = browserManager.importPasswordFile(trashAfter: trashFile) { passwordResult = result }
            }
        }
    }

    private func step(_ number: Int, _ text: LocalizedStringKey) -> some View {
        HStack(spacing: NookDesign.Spacing.lg) {
            Text("\(number)")
                .font(NookDesign.Font.caption)
                .frame(width: 20, height: 20)
                .background(Circle().fill(NookDesign.Surface.fillPressed))
            Text(text).font(NookDesign.Font.body)
            Spacer()
        }
        .padding(NookDesign.Spacing.lg)
        .accessibilityElement(children: .combine)
    }

    private func run() {
        guard let profile else { return }
        working = true
        Task {
            let summary = await browserManager.importChrome(profile, bookmarks: bookmarks, history: history)
            let choices = extensions ? await browserManager.chromeExtensionChoices(profile) : []
            working = false
            onImported(summary, choices)
        }
    }
}

// MARK: - Finished

struct ImportFinishedPanel: View {
    let source: ImportSource
    let summary: String
    let hasExtensions: Bool
    let onDone: () -> Void
    let onReview: () -> Void

    var body: some View {
        VStack(spacing: NookDesign.Spacing.xl) {
            VStack(spacing: NookDesign.Spacing.md) {
                NookSymbol("checkmark.circle", size: 40).accessibilityHidden(true)
                Text("Imported from \(source.name)").font(NookDesign.Font.heading)
                Text(summary).font(NookDesign.Font.secondary).foregroundStyle(.secondary).multilineTextAlignment(.center)
            }
            .accessibilityElement(children: .combine)
            HStack(spacing: NookDesign.Spacing.md) {
                ImportButton(title: "Done", primary: !hasExtensions, key: hasExtensions ? SwiftUI.KeyboardShortcut.cancelAction : .defaultAction, action: onDone)
                if hasExtensions { ImportButton(title: "Review Extensions", primary: true, key: .defaultAction, action: onReview) }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, NookDesign.Spacing.xl)
    }
}
