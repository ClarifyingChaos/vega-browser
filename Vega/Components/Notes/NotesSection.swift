// Licensed under GPL-3.0. See LICENSE.
//
//  NotesSection.swift
//  Vega
//
//  FORK: the current space's notes as rows above the sidebar's bottom bar. Hidden when the
//  space has none. shortcut: a section of its own, upgrade to rows among the tabs, as in Arc.
//

import SwiftUI
import VegaDesign
import VegaWeb
import VegaUI

struct NotesSection: View {
    @Environment(BrowserWindowState.self) private var windowState
    @State private var store = NoteStore.shared
    @State private var hovered: UUID?

    var body: some View {
        let notes = store.notes(in: windowState.spaceID)
        if !notes.isEmpty {
            VStack(alignment: .leading, spacing: VegaDesign.Spacing.rowGap) {
                Text("Notes")
                    .font(VegaDesign.Font.label)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, VegaDesign.Spacing.rowPadding)
                    .padding(.bottom, VegaDesign.Spacing.xs)
                ScrollView {
                    VStack(spacing: VegaDesign.Spacing.rowGap) {
                        ForEach(notes) { note in row(note) }
                    }
                }
                .scrollIndicators(.hidden)
                // Four rows show; more scroll.
                .frame(maxHeight: CGFloat(min(notes.count, 4)) * (VegaDesign.Tab.height + VegaDesign.Spacing.rowGap))
            }
            .padding(.horizontal, VegaDesign.Spacing.sidebarInset)
        }
    }

    private func row(_ note: Note) -> some View {
        let selected = store.openNote[windowState.id] == note.id
        return Button {
            store.openNote[windowState.id] = note.id
        } label: {
            HStack(spacing: VegaDesign.Spacing.md) {
                Image(systemName: "note.text")
                    .font(.system(size: VegaDesign.Size.rowGlyph))
                    .foregroundStyle(.secondary)
                    .frame(width: VegaDesign.Size.favicon)
                Text(note.displayTitle)
                    .font(VegaDesign.Tab.font)
                    .lineLimit(1)
                Spacer(minLength: 0)
                if hovered == note.id {
                    Button("Delete Note", systemImage: "xmark") { confirmDelete(note) }
                        .labelStyle(.iconOnly)
                        .buttonStyle(VegaIconButtonStyle(size: VegaDesign.Size.rowButton, radius: VegaDesign.Radius.sm))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, VegaDesign.Spacing.rowPadding)
            .frame(height: VegaDesign.Tab.height)
            .vegaTabSurface(selected: selected, hovered: hovered == note.id)
            .contentShape(VegaDesign.Radius.shape(VegaDesign.Tab.radius))
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 ? note.id : (hovered == note.id ? nil : hovered) }
        .contextMenu { Button("Delete Note", systemImage: "trash") { confirmDelete(note) } }
        .accessibilityLabel(note.displayTitle)
    }

    private func confirmDelete(_ note: Note) {
        let alert = SystemAlert.make("Delete \u{201C}\(note.displayTitle)\u{201D}?", "This note will be deleted. You can't undo this.",
                                     style: .warning, buttons: ["Delete", "Cancel"])
        alert.buttons.first?.hasDestructiveAction = true
        SystemAlert.present(alert) { response in
            if response == .alertFirstButtonReturn { store.delete(note.id) }
        }
    }
}
