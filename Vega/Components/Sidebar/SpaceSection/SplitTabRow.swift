import SwiftUI
import VegaDesign
import VegaTabsCore
import VegaWeb

/// The window's split pair shown as one sidebar row (from `BrowserWindowState.split`).
struct SplitTabRow: View {
    let left: Item
    let right: Item
    /// The drop zone the halves drag from.
    let zoneID: DropZoneID

    var body: some View {
        HStack(spacing: 0) {
            SplitHalfTab(item: left, zoneID: zoneID)
            Rectangle()
                .fill(VegaDesign.Surface.hairline)
                .frame(width: VegaDesign.Size.hairlineWidth)
                .padding(.vertical, VegaDesign.Spacing.sm)
            SplitHalfTab(item: right, zoneID: zoneID)
        }
        .frame(height: VegaDesign.Size.row)
        .clipShape(VegaDesign.Radius.shape(VegaDesign.Radius.md))
    }
}

private struct SplitHalfTab: View {
    let item: Item
    let zoneID: DropZoneID

    @State private var isHovering: Bool = false
    @State private var isCloseHovering: Bool = false
    @EnvironmentObject var browserManager: BrowserManager
    @Environment(BrowserWindowState.self) private var windowState
    @ObservedObject private var dragSession = VegaDragSessionManager.shared

    private var tabs: TabsController { browserManager.tabs }

    var body: some View {
        let title = tabs.title(for: item)
        let session = tabs.session(for: item.id)
        VegaDragSourceView(
            item: VegaDragItem(tabId: item.id, title: title, urlString: tabs.currentURL(for: item)?.absoluteString ?? ""),
            icon: session?.favicon,
            zoneID: zoneID,
            manager: dragSession
        ) {
            Button(action: { tabs.select(item.id, in: windowState) }) {
                HStack(spacing: VegaDesign.Spacing.md) {
                    ItemFavicon(item: item, session: session)
                        .frame(width: VegaDesign.Size.favicon, height: VegaDesign.Size.favicon)
                        .clipShape(VegaDesign.Radius.shape(VegaDesign.Radius.xs))
                    Text(title)
                        .font(VegaDesign.Font.body)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Spacer(minLength: VegaDesign.Spacing.xs)
                    if isHovering {
                        Button(action: { tabs.close(item.id) }) {
                            Image(systemName: "xmark")
                                .font(VegaDesign.Font.secondary)
                                .foregroundColor(.primary)
                                .frame(width: VegaDesign.Size.rowButton, height: VegaDesign.Size.rowButton)
                                .background(isCloseHovering ? VegaDesign.Surface.fillPressed : Color.clear)
                                .clipShape(VegaDesign.Radius.shape(VegaDesign.Radius.sm))
                        }
                        .buttonStyle(PlainButtonStyle())
                        .onHoverTracking { state in
                            isCloseHovering = state
                        }
                    }
                }
                .padding(.horizontal, VegaDesign.Spacing.rowPadding)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
            .onHoverTracking { hovering in
                withAnimation(VegaDesign.Motion.quick) {
                    isHovering = hovering
                }
            }
            .contextMenu {
                TabContextMenu(itemID: item.id, context: .split)
                    .environmentObject(browserManager)
                    .environment(windowState)
            }
        }
        .opacity(dragSession.draggedItem?.tabId == item.id ? VegaDesign.Surface.unloadedOpacity : 1)
        .background(backgroundColor)
        .overlay {
            if isActive {
                VegaDesign.Radius.shape(VegaDesign.Radius.md)
                    .strokeBorder(VegaDesign.Surface.hairline, lineWidth: VegaDesign.Size.hairlineWidth)
            }
        }
    }

    private var isActive: Bool {
        tabs.selectedItemID(in: windowState) == item.id
    }

    private var backgroundColor: Color {
        if isActive {
            return VegaDesign.Surface.raised
        } else if isHovering {
            return VegaDesign.Surface.fill
        } else {
            return Color.clear
        }
    }
}
