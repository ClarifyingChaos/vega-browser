// Licensed under GPL-3.0. See LICENSE.
import SwiftUI
import VegaDesign
import VegaTabsCore
import VegaUI
import AppKit
import Combine
import QuartzCore

/// A lifted tab retains its actual sidebar width, theme and pointer grab position.
/// The native drag session transports the item; this passive window draws its SwiftUI card.
final class VegaDragPreviewWindow: NSWindow {
    private var cancellables = Set<AnyCancellable>()
    private weak var manager: VegaDragSessionManager?

    @MainActor
    init(manager: VegaDragSessionManager) {
        self.manager = manager
        super.init(contentRect: .zero, styleMask: [.borderless], backing: .buffered, defer: true)
        isOpaque = false
        backgroundColor = .clear
        level = .floating
        ignoresMouseEvents = true
        hasShadow = false
        isReleasedWhenClosed = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        contentView = NSHostingView(rootView: VegaDragPreviewContent(manager: manager))

        manager.$draggedItem
            .map { $0 != nil }
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] show in
                guard let self else { return }
                if show {
                    if let manager = self.manager {
                        self.appearance = NSAppearance(named: manager.draggedColorScheme == .dark ? .darkAqua : .aqua)
                        self.updatePosition(manager.cursorScreenLocation)
                    }
                    self.orderFront(nil)
                } else {
                    self.orderOut(nil)
                }
            }
            .store(in: &cancellables)

        manager.cursorScreenLocationSubject
            .sink { [weak self] point in self?.updatePosition(point) }
            .store(in: &cancellables)
    }

    @MainActor
    private func updatePosition(_ point: CGPoint) {
        guard let manager, manager.isDragging else { return }
        let inset = VegaDesign.Tab.previewPadding
        let isTile: Bool
        if case .favorites = manager.activeZone { isTile = true } else { isTile = false }
        let sourceWasTile: Bool
        if case .favorites = manager.sourceZone { sourceWasTile = true } else { sourceWasTile = false }
        let rowWidth = sourceWasTile
            ? manager.sidebarScreenFrame.width - VegaDesign.Spacing.sidebarInset * 2
            : manager.sourceRowFrame.width
        let cardWidth = isTile ? VegaDesign.Size.favoriteTile : max(VegaDesign.Size.iconButton, rowWidth)
        let cardHeight = isTile ? VegaDesign.Size.favoriteTile : VegaDesign.Tab.height
        let grabFraction = manager.sourceRowFrame.width > 0 ? manager.grabOffset.x / manager.sourceRowFrame.width : 0.5
        // Follow both pointer axes, including inside the sidebar. Drop targets choose
        // the insertion slot; they must never pin the floating card to the sidebar edge.
        let x = point.x - cardWidth * grabFraction
        let y = point.y - manager.grabOffset.y - cardHeight / 2
        let frame = CGRect(x: x - inset, y: y - inset, width: cardWidth + inset * 2, height: cardHeight + inset * 2)
        if frame.size != self.frame.size { setFrame(frame, display: true) }
        else { setFrameOrigin(frame.origin) }
    }

    @MainActor
    func land(on cardFrame: CGRect, completion: @escaping () -> Void) {
        let inset = VegaDesign.Tab.previewPadding
        let frame = cardFrame.insetBy(dx: -inset, dy: -inset)
        NSAnimationContext.runAnimationGroup { context in
            context.duration = VegaDesign.Motion.tabLandingDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            animator().setFrame(frame, display: true)
        } completionHandler: {
            MainActor.assumeIsolated { completion() }
        }
    }
}

private struct VegaDragPreviewContent: View {
    @ObservedObject var manager: VegaDragSessionManager

    private var isTile: Bool {
        if case .favorites = manager.activeZone { return true }
        return false
    }

    var body: some View {
        GeometryReader { geometry in
            let inset = VegaDesign.Tab.previewPadding
            let size = CGSize(width: max(1, geometry.size.width - inset * 2), height: max(1, geometry.size.height - inset * 2))
            ZStack {
                // Keep the space's colored material under the same selected-tab surface.
                SpaceChromeBackground(theme: manager.draggedTheme, accent: manager.draggedAccent, isActive: true, blursBehind: false)
                Color.clear.vegaTabSurface(selected: true)
                HStack(spacing: VegaDesign.Spacing.md) {
                    if let icon = manager.draggedIcon {
                        icon.resizable().scaledToFit()
                            .frame(width: VegaDesign.Size.favicon, height: VegaDesign.Size.favicon)
                            .clipShape(VegaDesign.Radius.shape(VegaDesign.Radius.xs))
                    } else {
                        Image(systemName: "globe")
                            .frame(width: VegaDesign.Size.favicon, height: VegaDesign.Size.favicon)
                            .foregroundStyle(.secondary)
                    }
                    if !isTile {
                        Text(manager.draggedItem?.title ?? "")
                            .font(VegaDesign.Tab.font)
                            .lineLimit(1)
                            .truncationMode(.tail)
                        Spacer(minLength: 0)
                    }
                }
                .padding(.horizontal, VegaDesign.Spacing.rowPadding)
                            }
            .frame(width: size.width, height: size.height)
            .clipShape(VegaDesign.Radius.shape(isTile ? VegaDesign.Radius.lg : VegaDesign.Tab.radius))
            .shadow(color: .black.opacity(VegaDesign.Tab.liftShadowOpacity), radius: VegaDesign.Tab.liftShadowRadius, y: VegaDesign.Tab.liftShadowY)
            .padding(inset)
        }
        .environment(\.colorScheme, manager.draggedColorScheme)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
