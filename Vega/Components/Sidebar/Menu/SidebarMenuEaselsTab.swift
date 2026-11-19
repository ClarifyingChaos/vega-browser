// Licensed under GPL-3.0. See LICENSE.
//
//  SidebarMenuEaselsTab.swift
//  Vega
//
//  FORK: the library's Easels, as in Arc: every easel, newest first, and a button to start one.
//

import SwiftUI
import VegaDesign
import VegaUI

struct SidebarMenuEaselsTab: View {
    @ObservedObject private var store = EaselStore.shared
    @State private var text = ""

    private var shown: [Easel] {
        let words = text.split(separator: " ")
        return store.easels.filter { easel in words.allSatisfy { easel.name.localizedCaseInsensitiveContains($0) } }
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: VegaDesign.Spacing.rowGap) {
                Button { EaselManager.shared.newEasel() } label: {
                    Label("New Easel", vegaIcon: "plus")
                        .font(VegaDesign.Font.body)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, VegaDesign.Spacing.rowPadding)
                        .padding(.vertical, VegaDesign.Spacing.sm)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                if shown.isEmpty {
                    Text(store.easels.isEmpty ? "An easel is a canvas for notes, links and images. Start one above, or add the page you're on from its menu." : "No easels match.")
                        .font(VegaDesign.Font.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding()
                }
                ForEach(shown) { easel in EaselRowView(easel: easel) }
            }
            .padding(.horizontal, VegaDesign.Spacing.md)
            .padding(.bottom, VegaDesign.Spacing.md)
        }
        .vegaScrollHeader {
            SidebarMenuSearchField(prompt: "Search Easels", text: $text)
                .padding(VegaDesign.Spacing.md)
        }
    }
}

private struct EaselRowView: View {
    let easel: Easel
    @State private var isHovered = false
    @State private var confirmingDelete = false

    var body: some View {
        HStack(spacing: VegaDesign.Spacing.md) {
            Image(systemName: "scribble.variable")
                .frame(width: VegaDesign.Size.favicon, height: VegaDesign.Size.favicon)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 0) {
                Text(easel.name.isEmpty ? "Untitled Easel" : easel.name)
                    .font(VegaDesign.Font.body)
                    .lineLimit(1)
                Text("\(easel.items.count) \(easel.items.count == 1 ? "item" : "items") · \(easel.modified.formatted(date: .abbreviated, time: .shortened))")
                    .font(VegaDesign.Font.secondary)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, VegaDesign.Spacing.rowPadding)
        .padding(.vertical, VegaDesign.Spacing.sm)
        .background(isHovered ? VegaDesign.Surface.fill : .clear, in: VegaDesign.Radius.shape(VegaDesign.Radius.md))
        .contentShape(VegaDesign.Radius.shape(VegaDesign.Radius.md))
        .onHoverTracking { hovered in withAnimation(VegaDesign.Motion.hover(hovered)) { isHovered = hovered } }
        .onTapGesture { EaselManager.shared.open(easel.id) }
        .contextMenu {
            Button("Open", vegaIcon: "arrow.up.forward.app") { EaselManager.shared.open(easel.id) }
            Button("Add This Page", vegaIcon: "plus") { EaselManager.shared.addCurrentPage(to: easel.id) }
                .disabled(EaselManager.shared.currentPage() == nil)
            Divider()
            Button("Delete Easel…", vegaIcon: "trash", role: .destructive) { confirmingDelete = true }
        }
        .confirmationDialog("Delete \u{201C}\(easel.name.isEmpty ? "Untitled Easel" : easel.name)\u{201D}?", isPresented: $confirmingDelete) {
            Button("Delete Easel", role: .destructive) { EaselManager.shared.delete(easel.id) }
            Button("Cancel", role: .cancel) {}
        } message: { Text("You can't undo this.") }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }
}
