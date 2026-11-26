// Licensed under GPL-3.0. See LICENSE.
//
//  BrowserImportDialog.swift
//  Nook
//
//  Created by Maciek Bagiński on 14/10/2025.
//
//

import AppKit
import NookDesign
import NookUI
import SwiftUI

struct BrowserImportDialog: View {
    @EnvironmentObject private var browserManager: BrowserManager
    let onCancel: () -> Void

    private enum Step {
        case pick, chrome, working
        case finished(ImportSource, String, [ExtensionChoice])
    }

    @State private var step = Step.pick
    @State private var source = ImportSource.firstAvailable

    var body: some View {
        DialogCard {
            ImportScroll {
                switch step {
                case .pick: picker
                case .chrome:
                    ChromeImportPanel(onBack: { step = .pick }) { step = .finished(.chrome, $0, $1) }
                case .working:
                    ProgressView("Importing\u{2026}").frame(maxWidth: .infinity).padding(NookDesign.Spacing.xxl)
                case .finished(let source, let summary, let choices):
                    ImportFinishedPanel(source: source, summary: summary, hasExtensions: !choices.isEmpty,
                                        onDone: onCancel) { review(choices) }
                }
            }
            .padding(NookDesign.Spacing.xs)
        }
        .padding(.vertical, NookDesign.Spacing.lg)
        .environmentObject(browserManager.gradientColorManager)
    }

    private var picker: some View {
        VStack(alignment: .leading, spacing: NookDesign.Spacing.xl) {
            HStack(spacing: NookDesign.Spacing.xl) {
                NookSymbol("square.and.arrow.down", size: 22)
                    .frame(width: 44, height: 44)
                    .background(NookDesign.Radius.shape(NookDesign.Radius.lg).fill(NookDesign.Surface.fillPressed))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: NookDesign.Spacing.xs) {
                    Text("Import your essentials").font(NookDesign.Font.heading)
                    Text("Choose the browser you are coming from.").font(NookDesign.Font.secondary).foregroundStyle(.secondary)
                }
            }
            BrowserPicker(selection: $source)
            HStack(spacing: NookDesign.Spacing.md) {
                NookSymbol("shield.lefthalf.filled", size: 16).accessibilityHidden(true)
                Text("Everything is read on this Mac. Nothing is uploaded.")
            }
            .font(NookDesign.Font.caption)
            .foregroundStyle(.secondary)
            HStack(spacing: NookDesign.Spacing.md) {
                Button("Maybe later", action: onCancel)
                    .buttonStyle(DialogButtonStyle(variant: .secondary))
                    .keyboardShortcut(.cancelAction)
                Button("Continue", action: start)
                    .buttonStyle(DialogButtonStyle(variant: .primary))
                    .keyboardShortcut(.defaultAction)
                    .disabled(!source.isAvailable)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func start() {
        switch source {
        case .chrome:
            step = .chrome
        case .safari:
            // Safari has no readable data folder: the person exports it, then picks that folder.
            let panel = NSOpenPanel()
            panel.canChooseFiles = false
            panel.canChooseDirectories = true
            panel.message = "In Safari, choose File \u{203A} Export Browsing Data\u{2026}, unzip the file, then select that folder."
            panel.prompt = "Import"
            guard panel.runModal() == .OK, let url = panel.url else { return }
            guard let contents = browserManager.importManager.checkSafariExport(at: url) else {
                return fail("Vega didn't find a Safari export in that folder.")
            }
            run(.safari) {
                await browserManager.importSafariData(from: url, importBookmarks: true, importHistory: true)
                return "\(contents.bookmarkCount) bookmarks \u{00B7} \(contents.historyCount) history entries"
            }
        case .arc:
            if browserManager.nookSettings?.didImportFromArc == true {
                let again = NSAlert()
                again.messageText = "Import from Arc again?"
                again.informativeText = "Spaces from your last import stay, so you'll end up with two of each."
                again.addButton(withTitle: "Import Again")
                again.addButton(withTitle: "Cancel")
                guard again.runModal() == .alertFirstButtonReturn else { return }
            }
            run(.arc) { await browserManager.importArcData() }
        case .dia:
            run(.dia) { await browserManager.importDiaData() }
        }
    }

    /// `work` returns what came in as a sentence, or nil when nothing did.
    private func run(_ source: ImportSource, _ work: @escaping @MainActor () async -> String?) {
        step = .working
        Task {
            guard let summary = await work() else {
                step = .pick
                return fail("Vega didn't find anything to import from \(source.name).")
            }
            let choices = source == .dia ? [] : await browserManager.extensionChoices(includingArc: source == .arc)
            step = .finished(source, summary, choices)
        }
    }

    private func fail(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "Couldn't import"
        alert.informativeText = message
        alert.runModal()
    }

    private func review(_ choices: [ExtensionChoice]) {
        let manager = browserManager
        onCancel()
        // The dialog showing now has to finish closing before the next one replaces it.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            manager.dialogManager.showDialog(
                ExtensionImportDialog(
                    choices: choices,
                    preview: { await manager.extensionManager?.consentPreview(of: $0) }
                ) { chosen in
                    manager.closeDialog()
                    manager.extensionManager?.install(chosen)
                },
                closesOnBackdropClick: false
            )
        }
    }
}

struct ExtensionImportDialog: DialogPresentable {
    let choices: [ExtensionChoice]
    let preview: @MainActor (ExtensionOffer) async -> ExtensionConsentPreview?
    let onDone: ([ExtensionOffer]) -> Void

    @State private var selection: ExtensionSelection

    init(
        choices: [ExtensionChoice],
        preview: @escaping @MainActor (ExtensionOffer) async -> ExtensionConsentPreview?,
        onDone: @escaping ([ExtensionOffer]) -> Void
    ) {
        self.choices = choices
        self.preview = preview
        self.onDone = onDone
        _selection = State(initialValue: ExtensionSelection(choices))
    }

    func dialogHeader() -> DialogHeader {
        DialogHeader(
            icon: "puzzlepiece.extension",
            title: "Bring your extensions",
            subtitle: ExtensionChoiceList.subtitle(for: choices)
        )
    }

    func dialogContent() -> some View {
        ExtensionChoiceList(choices: choices, selection: $selection, preview: preview)
    }

    func dialogFooter() -> DialogFooter {
        DialogFooter(
            rightButtons: [
                DialogButton(text: "Skip", keyboardShortcut: .escape) { onDone([]) },
                DialogButton(text: selection.installTitle, variant: .primary) {
                    onDone(selection.chosen(from: choices))
                },
            ]
        )
    }
}

