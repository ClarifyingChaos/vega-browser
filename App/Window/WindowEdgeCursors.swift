// Licensed under GPL-3.0. See LICENSE.
import AppKit

/// Shows the resize cursor along the window's edges and corners. The page, the sidebar and the title band all set
/// their own cursors right up to the border and covered AppKit's, so the pointer stayed an arrow where a drag resizes.
/// This view sits above them, takes no clicks (the drag itself is still the window's), and only sets the cursor.
@MainActor
final class WindowEdgeCursorView: NSView {
    private static let band: CGFloat = 5

    static func install(in window: NSWindow) {
        guard let frameView = window.contentView?.superview,
              !frameView.subviews.contains(where: { $0 is WindowEdgeCursorView }) else { return }
        let view = WindowEdgeCursorView(frame: frameView.bounds)
        view.autoresizingMask = [.width, .height]
        frameView.addSubview(view, positioned: .above, relativeTo: nil)
    }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(rect: .zero, options: [.mouseMoved, .mouseEnteredAndExited, .cursorUpdate, .activeAlways, .inVisibleRect], owner: self))
    }

    override func mouseMoved(with event: NSEvent) { update(for: event) }
    override func mouseEntered(with event: NSEvent) { update(for: event) }
    override func cursorUpdate(with event: NSEvent) { update(for: event) }

    private func update(for event: NSEvent) {
        guard let window, window.styleMask.contains(.resizable), !window.styleMask.contains(.fullScreen) else { return }
        guard let cursor = Self.cursor(at: convert(event.locationInWindow, from: nil), in: bounds) else { return }
        cursor.set()
    }

    /// The resize cursor for a point in the band along an edge, nil in the middle.
    static func cursor(at point: NSPoint, in bounds: NSRect) -> NSCursor? {
        let left = point.x <= band, right = point.x >= bounds.width - band
        let bottom = point.y <= band, top = point.y >= bounds.height - band
        let position: NSCursor.FrameResizePosition
        switch (left, right, top, bottom) {
        case (true, _, true, _): position = .topLeft
        case (_, true, true, _): position = .topRight
        case (true, _, _, true): position = .bottomLeft
        case (_, true, _, true): position = .bottomRight
        case (true, _, _, _): position = .left
        case (_, true, _, _): position = .right
        case (_, _, true, _): position = .top
        case (_, _, _, true): position = .bottom
        default: return nil
        }
        return NSCursor.frameResize(position: position, directions: .all)
    }
}
