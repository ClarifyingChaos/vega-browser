//
//      PinnedGrid.swift
//      Vega
//
//      Created by Maciek Bagiński on 30/07/2025.
//
import VegaTabsCore
import SwiftUI
import VegaDesign
import UniformTypeIdentifiers

struct PinnedGrid: View {
    let width: CGFloat
    let spaceID: UUID?

    @EnvironmentObject var browserManager: BrowserManager
    @Environment(BrowserWindowState.self) private var windowState
    @Environment(WindowRegistry.self) private var windowRegistry
    @ObservedObject private var dragSession = VegaDragSessionManager.shared
    private let maxColumns = 4

    init(width: CGFloat, spaceID: UUID? = nil) {
        self.width = width
        self.spaceID = spaceID
    }

    private var tabs: TabsController { browserManager.tabs }

    @ViewBuilder
    var body: some View {
        let effectiveSpaceID = spaceID ?? windowState.spaceID
        let items: [Item] = effectiveSpaceID.map { tabs.favorites(of: $0) } ?? []
        let colsCount: Int = columnCount(for: width, itemCount: items.count)
        let columns: [GridItem] = makeColumns(count: colsCount)

        let shouldAnimate = (windowRegistry.activeWindow?.id == windowState.id) && !browserManager.isSwitchingSpace

        if let spaceID = effectiveSpaceID {
            let zone = DropZoneID.favorites(spaceID: spaceID)
            if items.isEmpty {
                let isDragging = dragSession.isDragging

                VegaDropZoneHostView(
                    zoneID: zone,
                    layout: .grid(count: 0, columns: colsCount),
                    manager: dragSession,
                    onDrop: { id, position in tabs.dropOnFavorites(id, spaceID: spaceID, index: position.index) }
                ) {
                    VStack(spacing: VegaDesign.Spacing.md) {
                        Image(systemName: "star.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.secondary)

                        VStack(spacing: VegaDesign.Spacing.xxs) {
                            Text("Drag to add Favorites")
                                .font(VegaDesign.Font.label)
                                .foregroundStyle(.secondary)

                            Text("Favorites keep your most\nused sites and apps close")
                                .font(VegaDesign.Font.secondary)
                                .foregroundStyle(.tertiary)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, VegaDesign.Spacing.xl)
                    .padding(.horizontal, VegaDesign.Spacing.lg)
                    .background {
                        VegaDesign.Radius.shape(VegaDesign.Radius.lg)
                            .strokeBorder(style: StrokeStyle(lineWidth: VegaDesign.Size.hairlineWidth, dash: [VegaDesign.Spacing.sm, VegaDesign.Spacing.xs]))
                            .foregroundStyle(isDragging ? VegaDesign.Surface.dropBorderActive : VegaDesign.Surface.dropBorderIdle)
                    }
                    .background {
                        VegaDesign.Radius.shape(VegaDesign.Radius.lg)
                            .fill(isDragging ? VegaDesign.Surface.fillPressed : Color.clear)
                    }
                    .animation(VegaDesign.Motion.quick, value: isDragging)
                }
            } else {
                VegaDropZoneHostView(
                    zoneID: zone,
                    layout: .grid(count: items.count, columns: colsCount),
                    manager: dragSession,
                    onDrop: { id, position in tabs.dropOnFavorites(id, spaceID: spaceID, index: position.index) }
                ) {
                    LazyVGrid(columns: columns, alignment: .center, spacing: VegaDesign.Spacing.sm) {
                        let insertionIdx = insertionIndex(in: zone, items: items)

                        ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                            let isDraggedItem = dragSession.draggedItem?.tabId == item.id

                            if let ins = insertionIdx, ins == index, !isDraggedItem {
                                essentialsPlaceholder
                            }

                            PinnedTile(item: item, zone: zone)
                                .opacity(isDraggedItem ? 0.0 : 1.0)
                        }

                        if let ins = insertionIdx, ins >= items.count {
                            essentialsPlaceholder
                        }
                    }
                    .animation(VegaDesign.Motion.spring, value: insertionIndex(in: zone, items: items))
                }
                .contentShape(Rectangle())
                .fixedSize(horizontal: false, vertical: true)
                .animation(shouldAnimate ? VegaDesign.Motion.standard : nil, value: colsCount)
                .animation(shouldAnimate ? VegaDesign.Motion.standard : nil, value: items.count)
                .allowsHitTesting(!browserManager.isSwitchingSpace)
            }
        }
    }

    /// The insertion index for the grid during a drag, or nil when no placeholder should show.
    private func insertionIndex(in zone: DropZoneID, items: [Item]) -> Int? {
        guard dragSession.isDragging, dragSession.activeZone == zone,
              let position = dragSession.dropPosition, position.zone == zone else {
            return nil
        }
        // Reordering within the grid: no placeholder at the dragged tile's own slot.
        if dragSession.sourceZone == zone,
           let dragged = dragSession.draggedItem?.tabId,
           let from = items.firstIndex(where: { $0.id == dragged }),
           position.index == from || position.index == from + 1 {
            return nil
        }
        return position.index
    }

    private var essentialsPlaceholder: some View {
        VegaDesign.Radius.shape(VegaDesign.Radius.lg)
            .fill(VegaDesign.Surface.fillPressed)
            .frame(minWidth: VegaDesign.Size.essentialsTile, minHeight: VegaDesign.Size.essentialsTile)
    }

    private func columnCount(for width: CGFloat, itemCount: Int) -> Int {
        guard width > 0, itemCount > 0 else { return 1 }
        var cols = min(maxColumns, itemCount)
        while cols > 1 {
            let needed = CGFloat(cols) * VegaDesign.Size.essentialsTile + CGFloat(cols - 1) * VegaDesign.Spacing.sm
            if needed <= width { break }
            cols -= 1
        }
        return max(1, cols)
    }

    private func makeColumns(count: Int) -> [GridItem] {
        Array(
            repeating: GridItem(
                .flexible(minimum: VegaDesign.Size.essentialsTile),
                spacing: VegaDesign.Spacing.sm,
                alignment: .center
            ),
            count: count
        )
    }
}

private struct PinnedTile: View {
    let item: Item
    let zone: DropZoneID

    @EnvironmentObject var browserManager: BrowserManager
    @Environment(BrowserWindowState.self) private var windowState
    @ObservedObject private var dragSession = VegaDragSessionManager.shared

    private var tabs: TabsController { browserManager.tabs }

    var body: some View {
        let session = tabs.session(for: item.id)
        let url = tabs.currentURL(for: item)?.absoluteString ?? ""
        VegaDragSourceView(
            item: VegaDragItem(tabId: item.id, title: tabs.title(for: item), urlString: url),
            icon: session?.favicon,
            zoneID: zone,
            manager: dragSession
        ) {
            PinnedTabView(
                tabName: tabs.title(for: item),
                tabURL: url,
                tabIcon: ItemFavicon(item: item, session: session),
                isActive: tabs.selectedItemID(in: windowState) == item.id,
                isUnloaded: session?.isUnloaded ?? true,
                hasLeftPinnedURL: tabs.hasLeftHome(item.id),
                onResetToPinnedURL: { tabs.resetToHome(item.id) },
                action: { tabs.select(item.id, in: windowState) }
            )
            .frame(maxWidth: .infinity)
            .contextMenu {
                TabContextMenu(itemID: item.id, context: .favorite)
                    .environmentObject(browserManager)
                    .environment(windowState)
            }
            .onHoverTracking { hovering in
                browserManager.hoveredPinnedTabId = hovering ? item.id : nil
            }
        }
    }
}
