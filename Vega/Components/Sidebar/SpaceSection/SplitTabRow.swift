import SwiftUI

struct SplitTabRow: View {
    let left: Tab
    let right: Tab
    let spaceId: UUID

    let onActivate: (Tab) -> Void
    let onClose: (Tab) -> Void

    @EnvironmentObject var browserManager: BrowserManager
    @Environment(BrowserWindowState.self) private var windowState
    @ObservedObject private var dragSession = VegaDragSessionManager.shared

    var body: some View {
        HStack(spacing: 0) {
            SplitHalfTab(
                tab: left,
                side: .left,
                spaceId: spaceId,
                onActivate: { onActivate(left) },
                onClose: { onClose(left) }
            )
            Rectangle()
                .fill(VegaDesign.Surface.hairline)
                .frame(width: VegaDesign.Size.hairlineWidth)
                .padding(.vertical, VegaDesign.Spacing.sm)
            SplitHalfTab(
                tab: right,
                side: .right,
                spaceId: spaceId,
                onActivate: { onActivate(right) },
                onClose: { onClose(right) }
            )
        }
        .frame(height: VegaDesign.Size.row)
        .clipShape(VegaDesign.Radius.shape(VegaDesign.Radius.md))
    }
}

private struct SplitHalfTab: View {
    @ObservedObject var tab: Tab
    let side: SplitViewManager.Side
    let spaceId: UUID
    let onActivate: () -> Void
    let onClose: () -> Void

    @State private var isHovering: Bool = false
    @State private var isCloseHovering: Bool = false
    @EnvironmentObject var browserManager: BrowserManager
    @EnvironmentObject var splitManager: SplitViewManager
    @Environment(BrowserWindowState.self) private var windowState
    @ObservedObject private var dragSession = VegaDragSessionManager.shared

    var body: some View {
        VegaDragSourceView(
            item: VegaDragItem(tabId: tab.id, title: tab.displayName, urlString: tab.url.absoluteString),
            tab: tab,
            zoneID: .spaceRegular(tab.spaceId ?? spaceId),
            index: tab.index,
            manager: dragSession
        ) {
            ZStack {
                Button(action: onActivate) {
                    HStack(spacing: VegaDesign.Spacing.md) {
                        tab.favicon
                            .resizable()
                            .scaledToFit()
                            .frame(width: VegaDesign.Size.favicon, height: VegaDesign.Size.favicon)
                            .clipShape(VegaDesign.Radius.shape(VegaDesign.Radius.xs))
                        Text(tab.displayName)
                            .font(VegaDesign.Font.body)
                            .foregroundStyle(textTab)
                            .lineLimit(1)
                            .truncationMode(.tail)
                        Spacer(minLength: VegaDesign.Spacing.xs)
                        if isHovering {
                            Button(action: onClose) {
                                Image(systemName: "xmark")
                                    .font(VegaDesign.Font.secondary)
                                    .foregroundColor(textTab)
                                    .frame(width: VegaDesign.Size.rowButton, height: VegaDesign.Size.rowButton)
                                    .background(
                                        isCloseHovering
                                            ? VegaDesign.Surface.fillPressed
                                            : Color.clear
                                    )
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
                    TabContextMenu(tab: tab, context: .split)
                }
            }
        }
        .opacity(dragSession.draggedItem?.tabId == tab.id ? 0 : 1.0)
        .background(backgroundColor)
        .overlay {
            if isActive {
                VegaDesign.Radius.shape(VegaDesign.Radius.md)
                    .strokeBorder(VegaDesign.Surface.hairline, lineWidth: 1)
            }
        }
    }

    private var isActive: Bool {
        browserManager.currentTab(for: windowState)?.id == tab.id
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
    private var textTab: Color {
        .primary
    }

}
