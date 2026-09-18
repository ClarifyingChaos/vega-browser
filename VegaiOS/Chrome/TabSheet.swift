// Licensed under GPL-3.0 with the App Store exception in LICENSE-EXCEPTION.md.
//
//  TabSheet.swift
//  VegaiOS
//
//  The phone's tab surface: the macOS sidebar outline at phone width. It opens
//  large because it is the deliberate surface (find, reorder, pin); quick
//  switching is the swipe on the bar. It drops to medium on a drag.
//

import SwiftUI
import VegaDesign
import VegaTabsCore
import VegaUI
import VegaWeb

struct TabSheet: View {
    @EnvironmentObject private var model: BrowserModel
    @Environment(TabsController.self) private var tabs
    @Environment(BrowserWindowState.self) private var window
    @Environment(\.dismiss) private var dismiss

    @State private var detent: PresentationDetent = .large

    private var spaceID: UUID? { window.spaceID }

    private let columns = Array(
        repeating: GridItem(.flexible(), spacing: VegaDesign.Spacing.sm),
        count: 4
    )

    var body: some View {
        ScrollView {
            if let spaceID {
                LazyVStack(alignment: .leading, spacing: VegaDesign.Spacing.lg) {
                    favorites(spaceID)
                    TabSheetRows(spaceID: spaceID) { dismiss() }
                }
                .padding(VegaDesign.Spacing.rowPadding)
            }
        }
        .safeAreaInset(edge: .top) {
            header
        }
        .presentationDetents([.medium, .large], selection: $detent)
        .presentationDragIndicator(.visible)
    }

    private var header: some View {
        ZStack {
            // Centred regardless of the close button's width.
            SpacesList()
                .frame(height: VegaDesign.Spacing.xl)

            HStack {
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .frame(width: VegaDesign.Size.iconButton)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, VegaDesign.Spacing.rowPadding)
        // Clears the sheet's own drag indicator, which draws at the same top edge.
        .padding(.top, VegaDesign.Spacing.xxl)
        .padding(.bottom, VegaDesign.Spacing.md)
        .background(.bar)
    }

    @ViewBuilder
    private func favorites(_ spaceID: UUID) -> some View {
        let items = tabs.favorites(of: spaceID)
        if !items.isEmpty {
            LazyVGrid(columns: columns, spacing: VegaDesign.Spacing.sm) {
                ForEach(items, id: \.id) { item in
                    let session = tabs.session(for: item.id)
                    PinnedTabView(
                        tabName: tabs.title(for: item),
                        tabURL: item.url?.absoluteString ?? "",
                        tabIcon: ItemFavicon(item: item, session: session),
                        isActive: tabs.selectedItemID(in: window) == item.id,
                        isUnloaded: session?.isUnloaded ?? true,
                        hasLeftPinnedURL: tabs.hasLeftHome(item.id),
                        onResetToPinnedURL: { tabs.resetToHome(item.id) },
                        action: {
                            tabs.select(item.id, in: window)
                            dismiss()
                        }
                    )
                    .frame(maxWidth: .infinity)
                    // PinnedTabView takes a generic icon and no item id, so the
                    // menu is attached here rather than inside the shared view.
                    .contextMenu {
                        TabContextMenu(itemID: item.id, context: .favorite)
                            .environment(window)
                            .environment(tabs)
                            .environment(\.tabActions, model)
                    }
                    .draggable(item.id.uuidString)
                }
            }
            // The grid takes a drop anywhere in it; favorites append rather than
            // land at an index, the way the Mac's pin intent does.
            .dropDestination(for: String.self) { ids, _ in
                guard let first = ids.first, let dragged = UUID(uuidString: first) else { return false }
                tabs.pin(dragged, to: .favorites(spaceID: spaceID))
                Haptics.alignment()
                return true
            }
        }
    }
}
