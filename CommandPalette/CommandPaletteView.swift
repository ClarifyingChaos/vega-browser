// Licensed under GPL-3.0. See LICENSE.
//
//  CommandPaletteView.swift
//  Nook
//
//  Created by Maciek Bagiński on 28/07/2025.
//

import AppKit
import SwiftUI
import Garnish
import NookDesign
import NookSettings
import NookWeb
import NookUI

/// What a key does with the typed text, at the trailing edge of the field or a row: a label and a keycap.
private struct PaletteKeyHint: View {
    let label: String
    let key: String

    var body: some View {
        HStack(spacing: 6) {
            Text(label)
                .font(NookDesign.Font.body)
                .foregroundStyle(Color.secondary)

            Text(key)
                .font(NookDesign.Font.caption)
                .foregroundStyle(Color.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    NookDesign.Radius.shape(NookDesign.Radius.xs)
                        .fill(NookDesign.Surface.fill)
                )
                .overlay(
                    NookDesign.Radius.shape(NookDesign.Radius.xs)
                        .stroke(NookDesign.Surface.hairline, lineWidth: 0.5)
                )
        }
        .allowsHitTesting(false)
        .transition(
            .blur(intensity: 4, scale: 0.92)
            .animation(NookDesign.Motion.standard)
        )
    }
}

struct CommandPaletteView: View {
    @EnvironmentObject var browserManager: BrowserManager
    @Environment(BrowserWindowState.self) private var windowState
    @Environment(CommandPalette.self) private var commandPalette
    @EnvironmentObject var gradientColorManager: GradientColorManager
    @State private var searchManager = SearchManager()
    @Environment(\.nookSettings) var nookSettings

    @FocusState private var isSearchFocused: Bool
    @State private var text: String = ""
    @State private var selectedSuggestionIndex: Int = -1
    @State private var hoveredSuggestionIndex: Int? = nil
    @State private var userTypedText: String = ""
    @State private var isNavigatingSuggestion: Bool = false
    @State private var activeSiteSearch: SiteSearchEntry? = nil
    /// Set by a deletion, so backspacing out of a completion does not bring it straight back.
    @State private var completionSuppressed: Bool = false
    /// Shift held a beat, which moves the highlight to the Look It Up row.
    @State private var shiftHeld: Bool = false
    @State private var shiftHold: Task<Void, Never>?

    private var siteSearchMatch: SiteSearchEntry? {
        guard activeSiteSearch == nil else { return nil }
        return SiteSearchEntry.match(for: text, in: nookSettings.siteSearchEntries)
    }

    /// True while an input method is composing, i.e. the field editor holds marked text.
    ///
    /// SwiftUI delivers `onKeyPress` ahead of the text input context, so without this the
    /// palette eats the keys a CJK input method needs: Return commits a candidate rather
    /// than submitting, and the arrow keys pick candidates rather than moving through
    /// suggestions. Handlers return `.ignored` while this is true so the IME gets them.
    private var isComposing: Bool {
        (NSApp.keyWindow?.firstResponder as? NSTextInputClient)?.hasMarkedText() ?? false
    }

    /// Open tabs that match first, then the row for what was typed, then the rest. Index -1 is
    /// the top row, which Return takes: a matching tab is switched to rather than opened again.
    private var visibleSuggestions: [SearchManager.SearchSuggestion] {
        var found = searchManager.suggestions
        if activeSiteSearch != nil {
            found = found.filter {
                if case .search = $0.type { return true }
                return false
            }
        }
        // FORK: an empty field lists the open tabs, as Arc's command bar does.
        if activeSiteSearch == nil, userTypedText.trimmingCharacters(in: .whitespaces).isEmpty {
            return searchManager.openTabSuggestions()
        }
        // FORK: commands, as in Arc's command bar. ">" lists only commands.
        let typed = userTypedText.trimmingCharacters(in: .whitespaces)
        let hasPage = browserManager.tabs.activeWindowSession.map { ["http", "https"].contains($0.url.scheme?.lowercased()) } ?? false
        let commands = activeSiteSearch == nil
            ? PaletteCommands.matching(typed, in: browserManager, hasPage: hasPage).map { SearchManager.SearchSuggestion(text: $0.title, type: .command($0.id)) }
            : []
        if typed.hasPrefix(">") { return Array(commands.prefix(12)) }
        guard let primary = primarySuggestion else { return found }
        let rest = found.filter { row in
            switch row.type {
            case .tab, .history, .command: return true
            case .url, .search: return row.text.caseInsensitiveCompare(primary.text) != .orderedSame
            }
        }
        // FORK: matching open tabs above the typed row; Look It Up right under it; Vega's command rows after.
        let openTabs = Array(rest.filter(\.isOpenTab).prefix(3))
        let others = rest.filter { !$0.isOpenTab }
        let lookup = lookupRowIndex == nil ? [] : [primary]
        return openTabs + [primary] + lookup + commands.prefix(3) + others.prefix(max(0, 4 - openTabs.count - lookup.count))
    }

    /// Whether a matching open tab heads the list, so Return switches to it.
    private var topIsOpenTab: Bool {
        activeSiteSearch == nil && searchManager.suggestions.first?.isOpenTab == true
    }

    /// What Shift-Return looks up: the highlighted search row, else the typed text when Return
    /// would search it. Nil for an address, a site search, or with Look It Up unavailable.
    private var lookupText: String? {
        guard activeSiteSearch == nil, siteSearchMatch == nil, browserManager.lookupManager.isAvailable(in: windowState) else { return nil }
        let row = selectedSuggestionIndex >= 0 && selectedSuggestionIndex < visibleSuggestions.count
            ? visibleSuggestions[selectedSuggestionIndex] : primarySuggestion
        guard let row, case .search = row.type else { return nil }
        let request = row.text.trimmingCharacters(in: .whitespacesAndNewlines)
        return request.isEmpty ? nil : request
    }

    /// The Look It Up row's place, right under the Return row, when Return would search. Judged
    /// on the typed text, not the field's, so the rows hold still while the arrows move.
    private var lookupRowIndex: Int? {
        guard activeSiteSearch == nil,
              SiteSearchEntry.match(for: userTypedText, in: nookSettings.siteSearchEntries) == nil,
              browserManager.lookupManager.isAvailable(in: windowState),
              !userTypedText.trimmingCharacters(in: .whitespaces).hasPrefix(">"),
              let primary = primarySuggestion, case .search = primary.type else { return nil }
        // Right under the typed row, which sits below up to three matching open tabs.
        return min(3, searchManager.suggestions.filter(\.isOpenTab).count) + 1
    }

    /// The row drawn selected. With Shift down on the Return row, that is the Look It Up row.
    private var highlightedIndex: Int {
        if shiftHeld, selectedSuggestionIndex <= 0, let lookupRowIndex { return lookupRowIndex }
        return max(selectedSuggestionIndex, 0)
    }

    /// What Return does with what was typed: the completed host, the address, or a search.
    private var primarySuggestion: SearchManager.SearchSuggestion? {
        let typed = userTypedText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !typed.isEmpty else { return nil }
        if let host = completionHost { return SearchManager.SearchSuggestion(text: host, type: .url) }
        return SearchManager.SearchSuggestion(text: typed, type: activeSiteSearch == nil && isLikelyURL(typed) ? .url : .search)
    }

    private static let shiftHoldDelay: Duration = .milliseconds(180)

    let commandPaletteWidth: CGFloat = 765
    let commandPaletteHorizontalPadding: CGFloat = 10
    
    /// Active window width
    private var currentWindowWidth: CGFloat {
        // FORK: this window's own width. The key window can be another, narrower one (a helper or
        // popup) while typing, which shrank the palette to a sliver.
        return windowState.window?.frame.width ?? NSApplication.shared.keyWindow?.frame.width ?? 0
    }
    
    /// Check if the command palette fits in the window
    private var isWindowTooNarrow: Bool {
        let requiredWidth = commandPaletteWidth + (commandPaletteHorizontalPadding * 2)
        return currentWindowWidth <= requiredWidth
    }
    
    /// Caclulate the correct command palette width
    private var effectiveCommandPaletteWidth: CGFloat {
        if isWindowTooNarrow {
            return max(200, currentWindowWidth - (commandPaletteHorizontalPadding * 2))
        } else {
            return commandPaletteWidth
        }
    }

    var body: some View {
        let isVisible = commandPalette.isVisible
        let textFieldColor: Color = text.isEmpty ? .secondary : .primary

        return ZStack {
            // FORK: a light dim behind the palette, as for any modal task, so it stands apart
            // from the page however dark or busy that page is.
            Color.black.opacity(NookDesign.Surface.modalDim)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .backgroundDraggable(onClick: {
                    commandPalette.close()
                })

            VStack {
                Spacer()
                HStack {
                    Spacer()
                    VStack {
                        VStack(alignment: .center,spacing: 6) {
                            HStack(spacing: 15) {
                                Image(systemName: leadingIconName)
                                .id(leadingIconName)
                                .transition(.blur(intensity: 2, scale: 0.6).animation(NookDesign.Motion.standard))
                                .font(NookDesign.Font.bodyRegular)
                                .foregroundStyle(Color.primary)
                                .frame(width: 15)

                                if let site = activeSiteSearch {
                                    Text(site.name)
                                        .font(NookDesign.Font.label)
                                        .foregroundStyle(Garnish.contrastingShade(of: site.color, targetRatio: 4.5, blendStyle: .strong) ?? .white)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 4)
                                        .background(site.color)
                                        .clipShape(Capsule())
                                        .transition(
                                            .blur(intensity: 8, scale: 0.6)
                                            .animation(NookDesign.Motion.spring)
                                        )
                                }

                                ZStack(alignment: .trailing) {
                                    TextField(
                                        activeSiteSearch != nil
                                            ? "Search \(activeSiteSearch!.name)..."
                                            : "Search or enter URL...",
                                        text: $text
                                    )
                                    .textFieldStyle(.plain)
                                    .font(.system(size: 17, weight: .regular)) // FORK: Arc's input, measured from its screenshot (17 pt regular; was 17 semibold)
                                    .foregroundColor(textFieldColor)
                                    .tint(gradientColorManager.accentColor)
                                    .overlay(alignment: .leading) {
                                        if let suffix = inlineCompletionSuffix {
                                            (Text(text).foregroundColor(.clear) + Text(suffix).foregroundColor(.secondary))
                                                .font(.system(size: 17, weight: .regular))
                                                .lineLimit(1)
                                                .allowsHitTesting(false)
                                        }
                                    }
                                    .focused($isSearchFocused)
                                    .onKeyPress(.tab) {
                                        if isComposing { return .ignored }
                                        if let match = siteSearchMatch, activeSiteSearch == nil {
                                            withAnimation(NookDesign.Motion.spring) {
                                                activeSiteSearch = match
                                            }
                                            text = ""
                                            return .handled
                                        }
                                        if acceptInlineCompletion() { return .handled }
                                        // With nothing selected, Tab moves to the first suggestion. It passes the
                                        // Look It Up row, so Tab twice still opens that suggestion.
                                        let firstSuggestion = lookupRowIndex == nil ? 1 : 2
                                        if selectedSuggestionIndex < 0 && visibleSuggestions.count > firstSuggestion {
                                            navigateSuggestions(direction: 1)
                                            if selectedSuggestionIndex < firstSuggestion { navigateSuggestions(direction: 1) }
                                            return .handled
                                        }
                                        // Tab with a selected suggestion = accept it (same as Enter)
                                        if selectedSuggestionIndex >= 0 && selectedSuggestionIndex < visibleSuggestions.count {
                                            selectRow(selectedSuggestionIndex)
                                            return .handled
                                        }
                                        return .ignored
                                    }
                                    .onKeyPress(keys: [.return]) { press in
                                        if isComposing { return .ignored }
                                        // Shift-Return looks a search up. On an address it is Return.
                                        if press.modifiers.contains(.shift), let request = lookupText {
                                            startLookup(request)
                                            return .handled
                                        }
                                        handleReturn()
                                        return .handled
                                    }
                                    .onKeyPress(.rightArrow) {
                                        if isComposing || !caretIsAtEnd { return .ignored }
                                        return acceptInlineCompletion() ? .handled : .ignored
                                    }
                                    .onKeyPress(.upArrow) {
                                        if isComposing { return .ignored }
                                        navigateSuggestions(direction: -1)
                                        return .handled
                                    }
                                    .onKeyPress(.downArrow) {
                                        if isComposing { return .ignored }
                                        navigateSuggestions(direction: 1)
                                        return .handled
                                    }
                                    .onKeyPress(.escape) {
                                        if isComposing { return .ignored }
                                        if activeSiteSearch != nil {
                                            withAnimation(NookDesign.Motion.standard) {
                                                activeSiteSearch = nil
                                            }
                                            return .handled
                                        }
                                        commandPalette.close()
                                        return .handled
                                    }
                                    .onKeyPress(keys: [.delete]) { press in
                                        if isComposing { return .ignored }
                                        if press.modifiers.contains(.shift), removeSelectedHistoryRow() { return .handled }
                                        if activeSiteSearch != nil && text.isEmpty {
                                            withAnimation(NookDesign.Motion.standard) {
                                                activeSiteSearch = nil
                                            }
                                            return .handled
                                        }
                                        return .ignored
                                    }
                                    .onKeyPress(characters: CharacterSet(charactersIn: "\u{7F}")) { press in
                                        if isComposing { return .ignored }
                                        if press.modifiers.contains(.shift), removeSelectedHistoryRow() { return .handled }
                                        if activeSiteSearch != nil && text.isEmpty {
                                            withAnimation(NookDesign.Motion.standard) {
                                                activeSiteSearch = nil
                                            }
                                            return .handled
                                        }
                                        return .ignored
                                    }
                                    .onChange(of: text) { _, newValue in
                                        if isNavigatingSuggestion {
                                            isNavigatingSuggestion = false
                                            return
                                        }
                                        // Shift for a capital letter is not Shift for the second row until it stays down.
                                        holdShift(NSEvent.modifierFlags.contains(.shift))
                                        completionSuppressed = newValue.count < userTypedText.count
                                        userTypedText = newValue
                                        searchManager.searchSuggestions(
                                            for: newValue
                                        )
                                        selectedSuggestionIndex = -1
                                    }
                                    .onModifierKeysChanged(mask: .shift) { _, new in
                                        holdShift(new.contains(.shift))
                                    }

                                    if activeSiteSearch == nil, let match = siteSearchMatch {
                                        PaletteKeyHint(label: "Search \(match.name)", key: "Tab")
                                    }
                                }
                            }
                            .animation(NookDesign.Motion.spring, value: activeSiteSearch != nil)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 8)

                            if !visibleSuggestions.isEmpty {
                                Capsule()
                                    .fill(NookDesign.Surface.hairline)
                                    .frame(height: 0.5)
                                    .frame(maxWidth: .infinity)
                            }

                            if !visibleSuggestions.isEmpty {
                                CommandPaletteSuggestionsListView(
                                    suggestions: visibleSuggestions,
                                    selectedIndex: highlightedIndex,
                                    lookupIndex: lookupRowIndex,
                                    hoveredIndex: $hoveredSuggestionIndex,
                                    onSelect: { index in
                                        selectRow(index)
                                    }
                                )
                            }
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity)
                        .frame(width: effectiveCommandPaletteWidth)
                        // FORK: dark glass in any theme, as Arc's command bar is.
                        .environment(\.colorScheme, .dark)
                        .nookGlassSurface(in: NookDesign.Radius.shape(14), tint: .black.opacity(0.6)) // FORK: Arc's ~14 pt corner (was 24)
                        .animation(
                            NookDesign.Motion.quick,
                            value: searchManager.suggestions.count
                        )
                        Spacer()
                    }
                    .frame(
                        width: effectiveCommandPaletteWidth,
                        height: 328
                    )

                    Spacer()
                }
                Spacer()
            }

        }
        .allowsHitTesting(isVisible)
        .opacity(isVisible ? 1.0 : 0.0)
        .onChange(of: commandPalette.isVisible) { _, newVisible in
            if newVisible {
                searchManager.setTabs(browserManager.tabs, window: windowState)
                searchManager.setHistoryManager(browserManager.historyManager)
                searchManager.updateSpaceContext()

                text = commandPalette.prefilledText
                userTypedText = commandPalette.prefilledText
                // FORK: with the open tabs listed, the first is chosen, as in Arc.
                selectedSuggestionIndex = text.isEmpty ? 0 : -1
                // A Shift let go while another app was in front never reported its release.
                shiftHeld = NSEvent.modifierFlags.contains(.shift)

                DispatchQueue.main.async {
                    isSearchFocused = true
                    DispatchQueue.main.async {
                        NSApplication.shared.sendAction(
                            #selector(NSText.selectAll(_:)),
                            to: nil,
                            from: nil
                        )
                    }
                }
            } else {
                isSearchFocused = false
                searchManager.clearSuggestions()
                text = ""
                userTypedText = ""
                activeSiteSearch = nil
                selectedSuggestionIndex = -1
            }
        }
        .onChange(of: windowState.spaceID) { _, _ in
            if commandPalette.isVisible {
                searchManager.updateSpaceContext()
                searchManager.clearSuggestions()
            }
        }
        .onChange(of: searchManager.suggestions.count) { _, _ in
            let count = visibleSuggestions.count
            if count == 0 {
                selectedSuggestionIndex = -1
            } else if selectedSuggestionIndex >= count {
                // Never onto the Look It Up row, where Return would start a lookup nobody chose.
                selectedSuggestionIndex = count - 1 == lookupRowIndex ? -1 : count - 1
            }
        }
        .onChange(of: commandPalette.prefilledText) { _, newValue in
            if isVisible {
                text = newValue
                userTypedText = newValue
                DispatchQueue.main.async {
                    isSearchFocused = true
                }
            }
        }
    }

    // MARK: - Suggestions List Subview
    private struct CommandPaletteSuggestionsListView: View {
        let suggestions: [SearchManager.SearchSuggestion]
        let selectedIndex: Int
        /// The row that is Look It Up for the typed text, when there is one.
        let lookupIndex: Int?
        @Binding var hoveredIndex: Int?
        let onSelect: (Int) -> Void
        @EnvironmentObject var gradientColorManager: GradientColorManager
        @EnvironmentObject var browserManager: BrowserManager

        private func commandSymbol(_ id: String) -> String { PaletteCommands.symbol(for: id, in: browserManager) }

        var body: some View {
            LazyVStack(spacing: 5) {
                ForEach(suggestions.indices, id: \.self) { index in
                    let suggestion = suggestions[index]
                    let isHovered = hoveredIndex == index
                    // Rows keep the text roles on a neutral fill, so the chosen row reads on any accent.
                    row(for: suggestion, isSelected: selectedIndex == index, isLookup: index == lookupIndex)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 11)
                        .background(
                            selectedIndex == index
                                ? gradientColorManager.accentColor
                                : isHovered
                                    ? NookDesign.Surface.fill
                                    : .clear
                        )
                        .clipShape(
                            NookDesign.Radius.shape(NookDesign.Radius.sm)
                        )
                        .font(NookDesign.Font.label)
                        .foregroundStyle(.primary)
                        .contentShape(NookDesign.Radius.shape(NookDesign.Radius.sm))
                        .onHoverTracking { hovering in
                            withAnimation(NookDesign.Motion.hover(hovering)) {
                                if hovering {
                                    hoveredIndex = index
                                } else {
                                    hoveredIndex = nil
                                }
                            }
                        }
                        .onTapGesture { onSelect(index) }
                }
            }
        }

        @ViewBuilder
        private func row(
            for suggestion: SearchManager.SearchSuggestion,
            isSelected: Bool,
            isLookup: Bool
        ) -> some View {
            switch suggestion.type {
            case .search where isLookup:
                HStack(spacing: NookDesign.Spacing.md) {
                    GenericSuggestionItem(
                        icon: Image(systemName: "sparkle.magnifyingglass"),
                        text: suggestion.text,
                        isSelected: isSelected
                    )
                    PaletteKeyHint(label: "Look It Up", key: "⇧⏎")
                }
            case .tab(let tab):
                TabSuggestionItem(tab: tab, isSelected: isSelected)
            case .history(let entry):
                HistorySuggestionItem(entry: entry, isSelected: isSelected)
            case .url:
                GenericSuggestionItem(
                    icon: Image(systemName: "link"),
                    text: suggestion.text,
                    isSelected: isSelected
                )
            case .search:
                GenericSuggestionItem(
                    icon: Image(systemName: "magnifyingglass"),
                    text: suggestion.text,
                    isSelected: isSelected
                )
            case .command(let id):
                GenericSuggestionItem(
                    icon: Image(systemName: commandSymbol(id)),
                    text: suggestion.text,
                    isSelected: isSelected
                )
            }
        }
    }

    private func handleReturn() {
        if let site = activeSiteSearch {
            let query: String
            if selectedSuggestionIndex >= 0 && selectedSuggestionIndex < visibleSuggestions.count {
                query = visibleSuggestions[selectedSuggestionIndex].text
            } else {
                query = text
            }
            guard !query.isEmpty else { return }
            let navigateURL: String
            if let url = site.searchURL(for: query) {
                navigateURL = url.absoluteString
            } else {
                // Fallback: search on the site's domain directly
                navigateURL = "https://\(site.domain)/search?q=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query)"
            }
            if let url = URL(string: navigateURL) {
                open(url)
            }
            text = ""
            activeSiteSearch = nil
            selectedSuggestionIndex = -1
            commandPalette.close()
            return
        }

        // ">" lists commands only: Return runs the first one.
        if selectedSuggestionIndex < 0, userTypedText.trimmingCharacters(in: .whitespaces).hasPrefix(">"), let first = visibleSuggestions.first {
            selectSuggestion(first)
            return
        }
        if selectedSuggestionIndex >= 0
            && selectedSuggestionIndex < visibleSuggestions.count
        {
            selectRow(selectedSuggestionIndex)
        } else if !visibleSuggestions.isEmpty {
            // The highlighted top row: a matching open tab, what was typed, or with nothing
            // typed the most recent tab.
            selectRow(0)
        }
    }

    /// Return, Tab or a click on a row: the Look It Up row starts a lookup, any other opens.
    private func selectRow(_ index: Int) {
        guard visibleSuggestions.indices.contains(index) else { return }
        let suggestion = visibleSuggestions[index]
        if index == lookupRowIndex {
            startLookup(suggestion.text)
        } else {
            selectSuggestion(suggestion)
        }
    }

    /// Draws the Look It Up row selected once Shift has stayed down a beat, so a capital does not flash it.
    private func holdShift(_ down: Bool) {
        shiftHold?.cancel()
        shiftHeld = false
        guard down else { return }
        shiftHold = Task { @MainActor in
            try? await Task.sleep(for: Self.shiftHoldDelay)
            if !Task.isCancelled { shiftHeld = true }
        }
    }

    private func startLookup(_ request: String) {
        browserManager.lookupManager.start(request, in: windowState)
        text = ""
        selectedSuggestionIndex = -1
        commandPalette.close()
    }

    private func selectSuggestion(_ suggestion: SearchManager.SearchSuggestion)
    {
        switch suggestion.type {
        case .tab(let match):
            browserManager.tabs.select(match.itemID, in: windowState)
        case .history(let historyEntry):
            open(historyEntry.url)
        case .command(let id):
            text = ""
            selectedSuggestionIndex = -1
            commandPalette.close()
            PaletteCommands.run(id, in: browserManager, window: windowState)
            return
        case .url, .search:
            // A page another window holds is not navigated from here; the text opens a new tab.
            if commandPalette.shouldNavigateCurrentTab, let session = browserManager.tabs.controllableSession(in: windowState) {
                session.navigate(to: suggestion.text)
            } else {
                // Normalize the URL/search query first, then create the tab with
                // the correct URL so the webview loads it directly without a race.
                let template = browserManager.nookSettings?.resolvedSearchEngineTemplate ?? SearchProvider.google.queryTemplate
                let resolved = normalizeURL(suggestion.text, queryTemplate: template)
                if let url = URL(string: resolved) {
                    browserManager.tabs.open(url: url, in: windowState, placement: .newTab)
                }
            }
        }

        text = ""
        activeSiteSearch = nil
        selectedSuggestionIndex = -1
        commandPalette.close()
    }

    /// Loads `url` in the selected page when the palette was opened to navigate it, else in a new tab.
    private func open(_ url: URL) {
        let navigateCurrent = commandPalette.shouldNavigateCurrentTab && windowState.selectedItemID != nil
        browserManager.tabs.open(url: url, in: windowState, placement: navigateCurrent ? .replaceCurrent : .newTab)
    }

    /// Makes the inline completion the field's text. False when none is showing.
    private func acceptInlineCompletion() -> Bool {
        guard let host = autofillTarget else { return false }
        text = host
        return true
    }

    private var caretIsAtEnd: Bool {
        guard let editor = NSApp.keyWindow?.firstResponder as? NSTextView else { return true }
        return editor.selectedRange().location >= (editor.string as NSString).length
    }

    private func navigateSuggestions(direction: Int) {
        let maxIndex = visibleSuggestions.count - 1

        // Row 0 is the Return row, which index -1 already stands for.
        if direction > 0 {
            guard maxIndex >= 1 else { return }
            selectedSuggestionIndex = min(max(selectedSuggestionIndex, 0) + 1, maxIndex)
        } else {
            selectedSuggestionIndex = selectedSuggestionIndex <= 1 ? -1 : selectedSuggestionIndex - 1
        }

        // The field shows the selected row, and keeps the typed text on the Return and Look It Up rows.
        let shown = selectedSuggestionIndex >= 0 && selectedSuggestionIndex < visibleSuggestions.count
            && selectedSuggestionIndex != lookupRowIndex
            ? displayTextForSuggestion(visibleSuggestions[selectedSuggestionIndex]) : userTypedText
        // onChange clears the flag, and it runs only when the text changes.
        guard shown != text else { return }
        isNavigatingSuggestion = true
        text = shown
    }

    private func stripScheme(_ urlString: String) -> String {
        for prefix in ["https://", "http://"] {
            if urlString.hasPrefix(prefix) {
                return String(urlString.dropFirst(prefix.count))
            }
        }
        return urlString
    }

    private func displayTextForSuggestion(_ suggestion: SearchManager.SearchSuggestion) -> String {
        switch suggestion.type {
        case .tab(let tab):
            return stripScheme(tab.url.absoluteString)
        case .history(let entry):
            return stripScheme(entry.url.absoluteString)
        case .url, .search, .command:
            return suggestion.text
        }
    }

    /// Globe once Return would navigate, which includes the case where only the inline
    /// completion makes it a URL.
    private var leadingIconName: String {
        guard activeSiteSearch == nil else { return "magnifyingglass" }
        return isLikelyURL(text) || autofillTarget != nil ? "globe" : "magnifyingglass"
    }

    /// Host that what was typed completes to, while it still prefixes it.
    private var completionHost: String? {
        // No completion under a matching open tab: Return switches to the tab.
        guard activeSiteSearch == nil, !topIsOpenTab,
              !completionSuppressed,
              !userTypedText.isEmpty,
              let host = searchManager.autofillHost,
              host.count > userTypedText.count,
              host.lowercased().hasPrefix(userTypedText.lowercased()) else { return nil }
        return host
    }

    /// The completion shown in the field. Nil while a suggestion is selected by hand, since the
    /// field then holds that row's text instead.
    private var autofillTarget: String? {
        guard selectedSuggestionIndex == -1, text == userTypedText else { return nil }
        return completionHost
    }

    /// Shift-Delete on a history row forgets that page and puts the typed text back.
    private func removeSelectedHistoryRow() -> Bool {
        guard selectedSuggestionIndex >= 0, selectedSuggestionIndex < visibleSuggestions.count,
              case .history(let entry) = visibleSuggestions[selectedSuggestionIndex].type else { return false }
        browserManager.historyManager.deleteHistoryEntry(entry.id)
        selectedSuggestionIndex = -1
        text = userTypedText
        searchManager.searchSuggestions(for: userTypedText)
        return true
    }

    private var inlineCompletionSuffix: String? {
        autofillTarget.map { String($0.dropFirst(text.count)) }
    }
}

private extension SearchManager.SearchSuggestion {
    var isOpenTab: Bool {
        if case .tab = type { return true }
        return false
    }
}
