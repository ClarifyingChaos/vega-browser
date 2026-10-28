// Licensed under GPL-3.0. See LICENSE.
import SwiftUI
import VegaDesign
import VegaTabsCore
import VegaUI
import VegaWeb

/// The window's split pair shown as one sidebar row (from `BrowserWindowState.split`).
/// The halves' visuals are `SplitHalfLabel` in VegaUI; this file is the drag source around them.
struct SplitTabRow: View {
    let left: Item
    let right: Item
    /// The drop zone the halves drag from.
    let zoneID: DropZoneID

    @Environment(BrowserWindowState.self) private var windowState
    @State private var isHovering = false

    /// The whole row is the selection while the window shows the pair.
    private var isActive: Bool {
        windowState.selectedItemID == left.id || windowState.selectedItemID == right.id
    }

    var body: some View {
        HStack(spacing: 0) {
            SplitHalfTab(item: left, zoneID: zoneID)
            Rectangle()
                .fill(VegaDesign.Surface.hairline)
                .frame(width: VegaDesign.Size.hairlineWidth)
                .padding(.vertical, VegaDesign.Spacing.sm)
            SplitHalfTab(item: right, zoneID: zoneID)
        }
        .frame(height: VegaDesign.Tab.height)
        .vegaTabSurface(selected: isActive, hovered: isHovering)
        .padding(.vertical, VegaDesign.Tab.verticalInset)
        .onHoverTracking { isHovering = $0 }
    }
}

private struct SplitHalfTab: View {
    let item: Item
    let zoneID: DropZoneID

    @Environment(TabsController.self) private var tabs
    @ObservedObject private var dragSession = VegaDragSessionManager.shared

    var body: some View {
        let session = tabs.session(for: item.id)
        VegaDragSourceView(
            item: VegaDragItem(tabId: item.id, title: tabs.title(for: item), urlString: tabs.currentURL(for: item)?.absoluteString ?? ""),
            icon: session?.favicon,
            zoneID: zoneID,
            manager: dragSession
        ) {
            SplitHalfLabel(item: item)
        }
        .opacity(dragSession.draggedItem?.tabId == item.id ? VegaDesign.Surface.unloadedOpacity : 1)
    }
}
