// Licensed under GPL-3.0. See LICENSE.
//
//  NotePageView.swift
//  Vega
//
//  FORK: a note's page, drawn over the web content as History is. Plain text: a title and a body.
//  shortcut: no rich text, upgrade when people ask for formatting.
//

import SwiftUI
import VegaDesign

struct NotePageView: View {
    let noteID: UUID
    let onClose: () -> Void

    @State private var title = ""
    @State private var text = ""
    @FocusState private var focus: Field?
    private enum Field { case title, body }

    var body: some View {
        ZStack {
            VegaDesign.Radius.shape(VegaDesign.Radius.page).fill(VegaDesign.Surface.windowBackground)
            VStack(alignment: .leading, spacing: VegaDesign.Spacing.md) {
                TextField("Title", text: $title)
                    .textFieldStyle(.plain)
                    .font(VegaDesign.Font.display)
                    .focused($focus, equals: .title)
                    .onSubmit { focus = .body }
                TextEditor(text: $text)
                    .font(VegaDesign.Font.bodyRegular.leading(.loose))
                    .scrollContentBackground(.hidden)
                    .focused($focus, equals: .body)
            }
            .frame(maxWidth: 680)
            .padding(.horizontal, VegaDesign.Spacing.xxxl)
            .padding(.top, VegaDesign.Spacing.xxxl)
            .padding(.bottom, VegaDesign.Spacing.xl)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .clipShape(VegaDesign.Radius.shape(VegaDesign.Radius.page))
        .onAppear { load() }
        .onChange(of: noteID) { _, _ in load() }
        .onChange(of: title) { _, new in NoteStore.shared.update(noteID, title: new) }
        .onChange(of: text) { _, new in NoteStore.shared.update(noteID, body: new) }
        .onDisappear { NoteStore.shared.writeNow() }
        .onExitCommand(perform: onClose)
    }

    private func load() {
        guard let note = NoteStore.shared.note(noteID) else { onClose(); return }
        title = note.title
        text = note.body
        focus = note.title.isEmpty && note.body.isEmpty ? .title : .body
    }
}
