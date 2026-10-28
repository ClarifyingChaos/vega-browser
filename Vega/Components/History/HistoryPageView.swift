// Licensed under GPL-3.0. See LICENSE.
//
//  HistoryPageView.swift
//  Vega
//
//  History as a page over the web content, as Arc's is: search, every visit grouped by day,
//  checkboxes to delete several at once. Opened with Cmd-Y; selecting a tab closes it.
//

import AppKit
import SwiftUI
import VegaDesign
import VegaWeb
import VegaUI

struct HistoryPageView: View {
    @EnvironmentObject var browserManager: BrowserManager
    @Environment(BrowserWindowState.self) private var windowState

    @State private var query = ""
    @State private var entries: [HistoryEntry] = []
    @State private var hasMore = false
    @State private var isLoading = false
    @State private var selection: Set<UUID> = []
    @State private var loadTask: Task<Void, Never>?
    @FocusState private var searchFocused: Bool

    private let navWidth: CGFloat = 260
    private let pageSize = 100
    private let contentMaxWidth: CGFloat = 960
    private let timeWidth: CGFloat = 52

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            navigation
                .frame(width: navWidth)
            Divider()
            VStack(spacing: VegaDesign.Spacing.lg) {
                toolbar
                list
            }
            .padding(.horizontal, VegaDesign.Spacing.xxxl)
            .padding(.top, VegaDesign.Spacing.xl)
            .frame(maxWidth: contentMaxWidth)
            .frame(maxWidth: .infinity)
        }
        .background(VegaDesign.Surface.windowBackground)
        .onAppear {
            searchFocused = true
            reload()
        }
        .onChange(of: query) { _, _ in reload() }
        // Choosing a tab or a space leaves History, as leaving Arc's history tab does.
        .onChange(of: windowState.selectedItemID) { _, _ in close() }
        .onChange(of: windowState.spaceID) { _, _ in close() }
        .onExitCommand(perform: close)
    }

    // MARK: - Navigation

    private var navigation: some View {
        VStack(alignment: .leading, spacing: VegaDesign.Spacing.xs) {
            HStack(spacing: VegaDesign.Spacing.md) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(VegaDesign.Font.titleLarge)
                Text("History")
                    .font(VegaDesign.Font.display)
                Spacer()
                Button("Close", systemImage: "xmark", action: close)
                    .labelStyle(.iconOnly)
                    .vegaIconButtons()
                    .help("Close History")
            }
            .padding(.bottom, VegaDesign.Spacing.lg)

            navRow("Vega History", symbol: "clock", isSelected: true) {}
            navRow("Clear Browsing Data…", symbol: "trash", isSelected: false) {
                browserManager.openSettings(tab: .privacy)
            }
            Spacer()
        }
        .padding(VegaDesign.Spacing.xl)
    }

    private func navRow(_ title: String, symbol: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(VegaDesign.Font.body)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, VegaDesign.Spacing.rowPadding)
                .frame(height: VegaDesign.Size.row + VegaDesign.Spacing.xs)
                .contentShape(VegaDesign.Radius.shape(VegaDesign.Radius.md))
        }
        .buttonStyle(.plain)
        .vegaRowSelection(isSelected)
    }

    // MARK: - Toolbar

    @ViewBuilder
    private var toolbar: some View {
        if selection.isEmpty {
            HStack(spacing: VegaDesign.Spacing.sm) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search history", text: $query)
                    .textFieldStyle(.plain)
                    .focused($searchFocused)
            }
            .font(VegaDesign.Font.body)
            .padding(.horizontal, VegaDesign.Spacing.lg)
            .frame(height: VegaDesign.Size.row + VegaDesign.Spacing.md)
            .vegaControlSurface(in: VegaDesign.Radius.shape(VegaDesign.Radius.lg))
        } else {
            HStack(spacing: VegaDesign.Spacing.md) {
                Text("\(selection.count) selected")
                    .font(VegaDesign.Font.label)
                    .contentTransition(.numericText())
                Spacer()
                Button("Cancel") { withAnimation(VegaDesign.Motion.standard) { selection.removeAll() } }
                    .buttonStyle(RectNavButtonStyle())
                Button("Delete", systemImage: "trash", action: deleteSelected)
                    .buttonStyle(RectNavButtonStyle())
            }
            .padding(.horizontal, VegaDesign.Spacing.lg)
            .frame(height: VegaDesign.Size.row + VegaDesign.Spacing.md)
            .vegaControlSurface(in: VegaDesign.Radius.shape(VegaDesign.Radius.lg))
        }
    }

    // MARK: - List

    private var list: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0, pinnedViews: []) {
                if entries.isEmpty && !isLoading {
                    Text(query.isEmpty ? "No history yet" : "No results")
                        .font(VegaDesign.Font.body)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, VegaDesign.Spacing.xxxl)
                }
                ForEach(Self.days(entries), id: \.day) { group in
                    Text(Self.title(for: group.day))
                        .font(VegaDesign.Font.heading)
                        .padding(.horizontal, VegaDesign.Spacing.lg)
                        .padding(.top, VegaDesign.Spacing.xl)
                        .padding(.bottom, VegaDesign.Spacing.md)
                    ForEach(group.entries) { entry in
                        HistoryPageRow(
                            entry: entry,
                            timeWidth: timeWidth,
                            isSelected: selection.contains(entry.id),
                            onToggle: { toggle(entry.id) },
                            onOpen: { open(entry.url, newTab: false) },
                            onOpenInNewTab: { open(entry.url, newTab: true) },
                            onDelete: { delete([entry.id]) })
                    }
                }
                if hasMore {
                    ProgressView()
                        .controlSize(.small)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, VegaDesign.Spacing.lg)
                        .id(entries.count)
                        .onAppear(perform: loadMore)
                }
            }
            .padding(.bottom, VegaDesign.Spacing.xl)
            .background(VegaDesign.Surface.fill, in: VegaDesign.Radius.shape(VegaDesign.Radius.lg))
            .padding(.bottom, VegaDesign.Spacing.xl)
        }
        .scrollIndicators(.automatic)
    }

    // MARK: - Data

    private func reload() {
        load(reset: true)
    }

    private func loadMore() {
        guard hasMore, !isLoading else { return }
        load(reset: false)
    }

    private func load(reset: Bool) {
        loadTask?.cancel()
        let text = query
        let offset = reset ? 0 : entries.count
        isLoading = true
        loadTask = Task { @MainActor in
            if reset && !text.isEmpty {
                do { try await Task.sleep(for: .milliseconds(125)) } catch { return }
            }
            let history = browserManager.historyManager
            let result = text.isEmpty
                ? await history.getHistory(days: HistoryManager.retentionDays, offset: offset, limit: pageSize)
                : await history.searchHistory(query: text, offset: offset, limit: pageSize)
            guard !Task.isCancelled else { return }
            entries = reset ? result.entries : entries + result.entries
            hasMore = result.hasMore
            isLoading = false
            if reset { selection.removeAll() }
        }
    }

    private func toggle(_ id: UUID) {
        if selection.contains(id) { selection.remove(id) } else { selection.insert(id) }
    }

    private func deleteSelected() {
        delete(Array(selection))
    }

    /// Rows leave in place, so paging by offset stays lined up with the store.
    private func delete(_ ids: [UUID]) {
        for id in ids { browserManager.historyManager.deleteHistoryEntry(id) }
        withAnimation(VegaDesign.Motion.standard) {
            entries.removeAll { ids.contains($0.id) }
            selection.subtract(ids)
        }
    }

    private func open(_ url: URL, newTab: Bool) {
        close()
        browserManager.tabs.open(url: url, in: windowState,
                                 placement: newTab || windowState.selectedItemID == nil ? .newTab : .replaceCurrent)
    }

    private func close() {
        withAnimation(VegaDesign.Motion.standard) { windowState.isHistoryPageVisible = false }
    }

    // MARK: - Days

    private struct Day {
        let day: Date
        let entries: [HistoryEntry]
    }

    private static func days(_ entries: [HistoryEntry]) -> [Day] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: entries) { calendar.startOfDay(for: $0.lastVisited) }
        return grouped.keys.sorted(by: >).map { day in
            Day(day: day, entries: grouped[day]!.sorted { $0.lastVisited > $1.lastVisited })
        }
    }

    private static func title(for day: Date) -> String {
        let full = day.formatted(.dateTime.weekday(.wide).day().month(.wide).year())
        let calendar = Calendar.current
        if calendar.isDateInToday(day) { return "Today - " + full }
        if calendar.isDateInYesterday(day) { return "Yesterday - " + full }
        return full
    }
}

private struct HistoryPageRow: View {
    let entry: HistoryEntry
    let timeWidth: CGFloat
    let isSelected: Bool
    let onToggle: () -> Void
    let onOpen: () -> Void
    let onOpenInNewTab: () -> Void
    let onDelete: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: VegaDesign.Spacing.lg) {
            Toggle("Select", isOn: Binding(get: { isSelected }, set: { _ in onToggle() }))
                .toggleStyle(.checkbox)
                .labelsHidden()
            Text(entry.lastVisited.formatted(date: .omitted, time: .shortened))
                .font(VegaDesign.Font.secondary.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: timeWidth, alignment: .leading)
            HistoryFavicon(url: entry.url)
            HStack(spacing: VegaDesign.Spacing.sm) {
                Text(entry.displayTitle)
                    .font(VegaDesign.Font.label)
                    .lineLimit(1)
                Text(entry.url.host ?? "")
                    .font(VegaDesign.Font.secondary)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            Menu {
                Button("Open in New Tab", action: onOpenInNewTab)
                Button("Copy Link") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(entry.url.absoluteString, forType: .string)
                }
                Divider()
                Button("Remove from History", action: onDelete)
            } label: {
                Image(systemName: "ellipsis")
            }
            .menuStyle(.button)
            .menuIndicator(.hidden)
            .buttonStyle(VegaIconButtonStyle())
            .opacity(isHovered ? 1 : 0)
        }
        .padding(.horizontal, VegaDesign.Spacing.lg)
        .frame(height: VegaDesign.Size.row + VegaDesign.Spacing.md)
        .background(isHovered || isSelected ? VegaDesign.Surface.fill : .clear, in: VegaDesign.Radius.shape(VegaDesign.Radius.md))
        .contentShape(VegaDesign.Radius.shape(VegaDesign.Radius.md))
        .padding(.horizontal, VegaDesign.Spacing.sm)
        .onHoverTracking { hovered in
            withAnimation(VegaDesign.Motion.quick) { isHovered = hovered }
        }
        .onTapGesture(perform: onOpen)
        .contextMenu {
            Button("Open", action: onOpen)
            Button("Open in New Tab", action: onOpenInNewTab)
            Divider()
            Button("Remove from History", action: onDelete)
        }
    }
}
