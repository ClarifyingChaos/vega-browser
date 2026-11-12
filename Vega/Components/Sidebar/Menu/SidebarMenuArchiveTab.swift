// Licensed under GPL-3.0. See LICENSE.
//
//  SidebarMenuArchiveTab.swift
//  Vega
//

import SwiftUI
import VegaDesign
import VegaTabsCore
import VegaWeb
import VegaUI

private struct ArchiveSection: Identifiable {
    var id: Date { day }
    let day: Date
    let entries: [ArchiveEntry]
}

/// The library's Archive: tabs closed or idle out of the tabs sections, newest first by day.
struct SidebarMenuArchiveTab: View {
    @Environment(BrowserWindowState.self) private var windowState
    @EnvironmentObject var browserManager: BrowserManager
    let onRestore: () -> Void
    @State private var text = ""

    private var sections: [ArchiveSection] {
        let words = text.split(separator: " ")
        let calendar = Calendar.current
        let matches = browserManager.tabs.archive.entries.reversed().filter { entry in
            words.allSatisfy { entry.title.localizedCaseInsensitiveContains($0) || (entry.host ?? "").localizedCaseInsensitiveContains($0) }
        }
        return Dictionary(grouping: matches) { calendar.startOfDay(for: $0.archivedAt) }
            .map { ArchiveSection(day: $0.key, entries: $0.value) }
            .sorted { $0.day > $1.day }
    }

    var body: some View {
        let sections = sections
        ScrollView {
            LazyVStack(spacing: VegaDesign.Spacing.rowGap) {
                if sections.isEmpty {
                    empty
                } else {
                    ForEach(sections) { section in
                        Text(title(for: section.day))
                            .font(VegaDesign.Font.captionStrong)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, VegaDesign.Spacing.rowPadding)
                            .padding(.top, VegaDesign.Spacing.md)
                            .padding(.bottom, VegaDesign.Spacing.xs)
                        ForEach(section.entries) { entry in
                            ArchiveRowView(entry: entry, restore: { restore(entry) }, remove: { remove(entry) })
                        }
                    }
                }
            }
            .padding(.horizontal, VegaDesign.Spacing.md)
            .padding(.bottom, VegaDesign.Spacing.md)
        }
        .vegaScrollHeader {
            SidebarMenuSearchField(prompt: "Search Archive", text: $text)
                .padding(VegaDesign.Spacing.md)
        }
    }

    private var empty: some View {
        VStack(spacing: VegaDesign.Spacing.md) {
            Image(systemName: "archivebox")
                .font(VegaDesign.Font.titleLarge)
                .foregroundStyle(.tertiary)
            Text("Tabs you close show up here for 30 days.")
                .font(VegaDesign.Font.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private func title(for day: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(day) { return "Today" }
        if calendar.isDateInYesterday(day) { return "Yesterday" }
        return day.formatted(.dateTime.weekday(.wide).month(.wide).day())
    }

    private func restore(_ entry: ArchiveEntry) {
        browserManager.tabs.restoreArchived(entry.id, in: windowState)
        onRestore()
    }

    private func remove(_ entry: ArchiveEntry) {
        withAnimation(VegaDesign.Motion.standard) { browserManager.tabs.removeFromArchive(entry.id) }
    }
}

private struct ArchiveRowView: View {
    let entry: ArchiveEntry
    let restore: () -> Void
    let remove: () -> Void
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: VegaDesign.Spacing.md) {
            if let url = entry.url {
                HistoryFavicon(url: url)
            } else {
                Image(systemName: "folder")
                    .frame(width: VegaDesign.Size.favicon, height: VegaDesign.Size.favicon)
                    .foregroundStyle(.secondary)
            }
            VStack(alignment: .leading, spacing: 0) {
                Text(entry.title.isEmpty ? (entry.host ?? "") : entry.title)
                    .font(VegaDesign.Font.body)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .fixedSize()
                Text(entry.host ?? "")
                    .font(VegaDesign.Font.secondary)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .fixedSize()
            }
            .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
            .vegaTrailingFade()
            Text(entry.archivedAt.formatted(date: .omitted, time: .shortened))
                .font(VegaDesign.Font.secondary)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, VegaDesign.Spacing.rowPadding)
        .padding(.vertical, VegaDesign.Spacing.sm)
        .background(isHovered ? VegaDesign.Surface.fill : .clear, in: VegaDesign.Radius.shape(VegaDesign.Radius.md))
        .contentShape(VegaDesign.Radius.shape(VegaDesign.Radius.md))
        .onHoverTracking { hovered in
            withAnimation(VegaDesign.Motion.hover(hovered)) { isHovered = hovered }
        }
        .onTapGesture(perform: restore)
        .contextMenu {
            Button("Restore", action: restore)
            Button("Remove from Archive", action: remove)
        }
    }
}
