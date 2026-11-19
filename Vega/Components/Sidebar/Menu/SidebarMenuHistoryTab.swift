// Licensed under GPL-3.0. See LICENSE.
//
//  SidebarMenuHistoryTab.swift
//  Vega
//
//  Created by Maciek Bagiński on 23/09/2025.
//

import AppKit
import FaviconFinder
import SwiftUI
import VegaDesign
import VegaWeb
import VegaUI

struct HistorySection: Identifiable {
    var id: String { title }
    let title: String
    let entries: [HistoryEntry]

    /// One row per run of neighbouring pages that share a title and a site: a sign-in redirect loop makes many
    /// addresses (each with its own query) that read the same, and ten identical rows only bury the list.
    var rows: [HistoryRow] {
        var rows: [HistoryRow] = []
        for entry in entries {
            if let last = rows.last, last.entry.displayTitle == entry.displayTitle, last.entry.url.host == entry.url.host {
                rows[rows.count - 1].ids.append(entry.id)
            } else {
                rows.append(HistoryRow(entry: entry, ids: [entry.id]))
            }
        }
        return rows
    }
}

/// A history row on screen: the newest page of a run, and the ids of every page the run folds together.
struct HistoryRow: Identifiable {
    let entry: HistoryEntry
    var ids: [UUID]
    var id: UUID { entry.id }
    var count: Int { ids.count }
}

enum TimeRange: String, CaseIterable {
    case today = "D"
    case week = "W"
    case month = "M"
    case all = "ALL"

    var days: Int {
        switch self {
        case .today: return 1
        case .week: return 7
        case .month: return 30
        case .all: return HistoryManager.retentionDays
        }
    }
}

struct SidebarMenuHistoryTab: View {
    @EnvironmentObject var browserManager: BrowserManager
    @State private var text: String = ""

    @State private var historyEntries: [HistoryEntry] = []
    @State private var groupedHistoryEntries: [HistorySection] = []
    @State private var selectedTimeRange: TimeRange = .week
    @State private var isLoading: Bool = false
    @State private var hasMoreResults: Bool = false
    @State private var isLoadingMore: Bool = false
    @State private var isShowingFilters: Bool = false
    @State private var isFiltersHovered: Bool = false

    @State private var historyTask: Task<Void, Never>?
    @State private var requestID = UUID()

    private let pageSize: Int = 50

    var body: some View {
        ScrollView {
            list
                .padding(.horizontal, VegaDesign.Spacing.md)
                .padding(.bottom, VegaDesign.Spacing.md)
        }
        // The rows scroll under the search field and filters, which float as filled controls with the
        // system's soft blur at the edge behind them, the way a macOS 26 toolbar does.
        .vegaScrollHeader {
            header
                .padding(VegaDesign.Spacing.md)
        }
        .onAppear {
            loadHistory()
        }
        .onChange(of: selectedTimeRange) { _, _ in
            loadHistory()
        }
        .onChange(of: browserManager.historyManager.currentProfileId) { _, _ in
            loadHistory()
        }
        .onDisappear { historyTask?.cancel() }
    }

    private var header: some View {
        VStack(spacing: VegaDesign.Spacing.md) {
            HStack(spacing: VegaDesign.Spacing.xs) {
                SidebarMenuSearchField(prompt: "Search history...", text: $text)
                    .onChange(of: text) { _, _ in loadHistory() }

                Button {
                    isShowingFilters.toggle()
                } label: {
                    HStack(spacing: VegaDesign.Spacing.xs) {
                        Image(systemName: isShowingFilters ? "line.horizontal.3.decrease.circle.fill" : "line.horizontal.3.decrease.circle")
                            .font(VegaDesign.Font.title)
                        Text("Filters")
                            .font(VegaDesign.Font.body)
                    }
                    .foregroundStyle(isShowingFilters || isFiltersHovered ? .primary : .secondary)
                    .padding(.horizontal, VegaDesign.Spacing.lg)
                    .frame(height: VegaDesign.Size.chromeControl)
                    .contentShape(VegaDesign.Radius.shape(VegaDesign.Radius.md))
                    .background(isShowingFilters || isFiltersHovered ? VegaDesign.Surface.fill : .clear, in: VegaDesign.Radius.shape(VegaDesign.Radius.md))
                }
                .buttonStyle(.plain)
                .animation(VegaDesign.Motion.quick, value: isShowingFilters)
                .animation(VegaDesign.Motion.quick, value: isFiltersHovered)
                .onHoverTracking { isFiltersHovered = $0 }
            }
            if isShowingFilters {
                FiltersSelectView(selectedTimeRange: $selectedTimeRange)
            }
        }
    }

    private var list: some View {
        LazyVStack(spacing: VegaDesign.Spacing.rowGap) {
            // A reload keeps the list on screen; only a first load shows the spinner.
            if isLoading && groupedHistoryEntries.isEmpty {
                HStack {
                    ProgressView()
                        .controlSize(.small)
                    Text("Loading history...")
                        .font(VegaDesign.Font.secondary)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else if groupedHistoryEntries.isEmpty {
                VStack(spacing: VegaDesign.Spacing.md) {
                    VegaSymbol("clock", size: 25)
                        .font(VegaDesign.Font.titleLarge)
                        .foregroundStyle(.tertiary)

                    Text(
                        text.isEmpty
                            ? "No history yet" : "No results found"
                    )
                    .font(VegaDesign.Font.body)
                    .foregroundStyle(.secondary)

                    if text.isEmpty {
                        Text(
                            "Visit some websites to see your history here"
                        )
                        .font(VegaDesign.Font.secondary)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else {
                ForEach(groupedHistoryEntries) { section in
                    Text(section.title)
                        .font(VegaDesign.Font.captionStrong)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, VegaDesign.Spacing.rowPadding)
                        .padding(.top, VegaDesign.Spacing.md)
                        .padding(.bottom, VegaDesign.Spacing.xs)

                    ForEach(section.rows) { row in
                        HistoryRowView(
                            entry: row.entry,
                            foldedCount: row.count,
                            onTap: { openInCurrentTab(row.entry.url) },
                            onOpenInNewTab: { openInNewTab(row.entry.url) },
                            onDelete: { row.ids.forEach(deleteEntryID) }
                        )
                    }
                }

                // Loads the next page when it scrolls into view, however short the last
                // section is. A new identity per page means a page that leaves it on
                // screen asks again, and one that pushes it off screen waits.
                if hasMoreResults {
                    HStack {
                        ProgressView()
                            .controlSize(.small)
                        Text("Loading more...")
                            .font(VegaDesign.Font.secondary)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, VegaDesign.Spacing.md)
                    .id(historyEntries.count)
                    .onAppear { loadMoreHistory() }
                }
            }
        }
    }

    // MARK: Functions

    private func loadHistory() {
        requestHistory(reset: true)
    }

    private func loadMoreHistory() {
        guard hasMoreResults, !isLoading, !isLoadingMore else { return }
        requestHistory(reset: false)
    }

    private func requestHistory(reset: Bool) {
        historyTask?.cancel()
        let id = UUID()
        requestID = id
        let query = text
        let days = selectedTimeRange.days
        let offset = reset ? 0 : historyEntries.count
        let profile = browserManager.historyManager.currentProfileId
        isLoading = reset
        isLoadingMore = !reset
        historyTask = Task { @MainActor in
            if reset && !query.isEmpty {
                do { try await Task.sleep(for: .milliseconds(125)) } catch { return }
            }
            let result: (entries: [HistoryEntry], hasMore: Bool)
            if query.isEmpty {
                result = await browserManager.historyManager.getHistory(days: days, offset: offset, limit: pageSize)
            } else {
                result = await browserManager.historyManager.searchHistory(query: query, offset: offset, limit: pageSize)
            }
            guard !Task.isCancelled, requestID == id,
                  browserManager.historyManager.currentProfileId == profile else { return }
            withAnimation(VegaDesign.Motion.standard) {
                historyEntries = reset ? result.entries : historyEntries + result.entries
                groupedHistoryEntries = groupHistoryEntries(historyEntries)
                hasMoreResults = result.hasMore
                isLoading = false
                isLoadingMore = false
            }
        }
    }

    /// Sections ordered by their newest visit, which is the order the labels describe.
    private func groupHistoryEntries(_ entries: [HistoryEntry])
        -> [HistorySection]
    {
        let calendar = Calendar.current
        let now = Date()
        let nowComponents = calendar.dateComponents([.year, .month, .weekOfYear], from: now)

        let grouped = Dictionary(grouping: entries) { entry in
            let components = calendar.dateComponents(
                [.year, .month, .weekOfYear],
                from: entry.lastVisited
            )

            if calendar.isDate(entry.lastVisited, inSameDayAs: now) {
                return "Today"
            } else if calendar.isDateInYesterday(entry.lastVisited) {
                return "Yesterday"
            } else if components.year == nowComponents.year
                && components.weekOfYear == nowComponents.weekOfYear
            {
                return "This Week"
            } else if let weekDiff = calendar.dateComponents(
                [.weekOfYear],
                from: entry.lastVisited,
                to: now
            ).weekOfYear {
                // Under seven days but in an earlier calendar week counts 0 whole weeks.
                if weekDiff <= 1 {
                    return "Last Week"
                } else if weekDiff <= 4 {
                    return "\(weekDiff) weeks ago"
                } else if components.year == nowComponents.year
                    && components.month == nowComponents.month
                {
                    return "This Month"
                } else if let monthDiff = calendar.dateComponents(
                    [.month],
                    from: entry.lastVisited,
                    to: now
                ).month {
                    if monthDiff == 1 {
                        return "Last Month"
                    } else if monthDiff <= 12 {
                        return "\(monthDiff) months ago"
                    } else {
                        let yearDiff =
                            calendar.dateComponents(
                                [.year],
                                from: entry.lastVisited,
                                to: now
                            ).year ?? 0
                        return yearDiff == 1
                            ? "Last Year" : "\(yearDiff) years ago"
                    }
                } else {
                    return "Older"
                }
            } else {
                return "Older"
            }
        }

        // Newest first inside each section, and sections by their newest entry: sorting the
        // titles put "10 months ago" above "2 months ago" and "2 months ago" above "2 weeks ago".
        return grouped
            .map { HistorySection(title: $0.key, entries: $0.value.sorted { $0.lastVisited > $1.lastVisited }) }
            .sorted { $0.entries[0].lastVisited > $1.entries[0].lastVisited }
    }

    private func openInCurrentTab(_ url: URL) {
        guard let window = browserManager.windowRegistry?.activeWindow else { return }
        browserManager.tabs.open(url: url, in: window, placement: window.selectedItemID == nil ? .newTab : .replaceCurrent)
    }

    private func openInNewTab(_ url: URL) {
        guard let window = browserManager.windowRegistry?.activeWindow else { return }
        browserManager.tabs.open(url: url, in: window, placement: .newTab)
    }

    /// Paging is by offset from what is on screen, so dropping the row here keeps the next page
    /// lined up with the store; reloading from the top lost every page past the first.
    private func deleteEntryID(_ id: UUID) {
        browserManager.historyManager.deleteHistoryEntry(id)
        withAnimation(VegaDesign.Motion.standard) {
            historyEntries.removeAll { $0.id == id }
            groupedHistoryEntries = groupHistoryEntries(historyEntries)
        }
    }
}

struct HistoryRowView: View {
    let entry: HistoryEntry
    /// How many pages this row stands for; more than one when a run of look-alike pages was folded.
    var foldedCount: Int = 1
    let onTap: () -> Void
    let onOpenInNewTab: () -> Void
    let onDelete: () -> Void

    @State private var isHovered: Bool = false

    var body: some View {
        HStack(spacing: VegaDesign.Spacing.md) {
            HistoryFavicon(url: entry.url)

            VStack(alignment: .leading, spacing: 0) {
                Text(entry.displayTitle)
                    .font(VegaDesign.Font.body)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .fixedSize()

                Text((entry.url.host ?? "") + (foldedCount > 1 ? " · \(foldedCount) pages" : ""))
                    .font(VegaDesign.Font.secondary)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .fixedSize()
            }
            .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
            .vegaTrailingFade()

            if isHovered {
                HStack(spacing: 0) {
                    Button(action: onDelete) {
                        Image(systemName: "trash")
                    }
                    .help("Remove from history")

                    Button(action: onOpenInNewTab) {
                        Image(systemName: "arrow.uturn.backward")
                    }
                    .help("Open in a new tab")
                }
                .font(VegaDesign.Font.caption)
                .buttonStyle(VegaIconButtonStyle())
                .transition(.opacity)
            }
        }
        .padding(.horizontal, VegaDesign.Spacing.rowPadding)
        .padding(.vertical, VegaDesign.Spacing.sm)
        .background(isHovered ? VegaDesign.Surface.fill : .clear, in: VegaDesign.Radius.shape(VegaDesign.Radius.md))
        .contentShape(VegaDesign.Radius.shape(VegaDesign.Radius.md))
        .onHoverTracking { hovered in
            withAnimation(VegaDesign.Motion.hover(hovered)) {
                isHovered = hovered
            }
        }
        .onTapGesture {
            onTap()
        }
        .contextMenu {
            Button("Open") { onTap() }
            Button("Open in New Tab") {
                onOpenInNewTab()
            }
            Divider()
            Button("Remove from History") { onDelete() }
        }
    }
}

/// A history page's favicon: the cache first, the network only for a row on screen.
struct HistoryFavicon: View {
    let url: URL
    @State private var favicon: SwiftUI.Image?

    var body: some View {
        (favicon ?? SwiftUI.Image(systemName: "globe"))
            .resizable()
            .scaledToFit()
            .frame(width: VegaDesign.Size.favicon, height: VegaDesign.Size.favicon)
            .foregroundStyle(.secondary)
            // Cancelled when the row scrolls away; the old onAppear Task kept fetching for rows long gone.
            .task(id: FaviconCache.key(for: url)) {
                guard url.scheme == "http" || url.scheme == "https", let host = FaviconCache.key(for: url) else { return }
                if let cached = await FaviconCache.shared.cachedImage(for: host) {
                    favicon = SwiftUI.Image(platformImage: cached)
                    return
                }
                guard let image = try? await FaviconFinder(url: url).fetchFaviconURLs().download().largest().image?.image,
                      !Task.isCancelled else { return }
                FaviconCache.shared.store(image, for: host)
                favicon = SwiftUI.Image(platformImage: FaviconCache.shared.image(for: host) ?? image)
            }
    }
}

struct FiltersSelectView: View {
    @Binding var selectedTimeRange: TimeRange

    var body: some View {
        VStack(alignment: .leading, spacing: VegaDesign.Spacing.md) {
            Text("When was the tab closed?")
                .font(VegaDesign.Font.secondary)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: VegaDesign.Spacing.sm) {
                HStack(spacing: VegaDesign.Spacing.sm) {
                    FiltersSelectButton(
                        text: "All time",
                        isActive: selectedTimeRange == .all
                    ) {
                        selectedTimeRange = .all
                    }
                    FiltersSelectButton(
                        text: "Today",
                        isActive: selectedTimeRange == .today
                    ) {
                        selectedTimeRange = .today
                    }
                    FiltersSelectButton(
                        text: "This week",
                        isActive: selectedTimeRange == .week
                    ) {
                        selectedTimeRange = .week
                    }
                }
                FiltersSelectButton(
                    text: "This month",
                    isActive: selectedTimeRange == .month
                ) {
                    selectedTimeRange = .month
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// A filter chip: a fill on hover, the selected row's surface when chosen.
struct FiltersSelectButton: View {
    var text: String
    var isActive: Bool
    var action: () -> Void

    @State private var isHovering: Bool = false

    var body: some View {
        Button {
            action()
        } label: {
            Text(text)
                .font(VegaDesign.Font.body)
                .foregroundStyle(isActive || isHovering ? .primary : .secondary)
                .lineLimit(1)
                .padding(.horizontal, VegaDesign.Spacing.lg)
                .frame(height: VegaDesign.Size.iconButton)
                .contentShape(VegaDesign.Radius.shape(VegaDesign.Radius.md))
                .background(!isActive && isHovering ? VegaDesign.Surface.fill : .clear, in: VegaDesign.Radius.shape(VegaDesign.Radius.md))
                .vegaRowSelection(isActive)
        }
        .buttonStyle(.plain)
        .animation(VegaDesign.Motion.hover(isHovering), value: isHovering)
        .animation(VegaDesign.Motion.standard, value: isActive)
        .onHoverTracking { state in
            isHovering = state
        }
    }
}
