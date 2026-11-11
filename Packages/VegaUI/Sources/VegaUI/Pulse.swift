// Licensed under GPL-3.0. See LICENSE.
import SwiftUI
import VegaDesign

public extension View {
    /// Fades in and out while `active`, and once through for an activity too brief to see. Style
    /// the view before this: on macOS the copy that shows is hosted outside the caller's environment.
    func vegaPulse(while active: Bool) -> some View {
        // The hidden original keeps the layout; the hosted copy over it is the one that fades.
        hidden().overlay { VegaPulse(active: active, content: self).allowsHitTesting(false) }
    }
}

#if os(macOS)
import AppKit

/// The fade runs in the render server, with no work on the main thread per frame. A SwiftUI
/// animation cost a display cycle per frame, and `symbolEffect(.pulse)` held the main thread
/// about 200 ms each time it started or stopped.
private struct VegaPulse<Content: View>: NSViewRepresentable {
    let active: Bool
    let content: Content
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSHostingView<Content> {
        let view = Host(rootView: content)
        // Sized by the overlay it fills, and not pushed down when that is under the title bar.
        view.sizingOptions = []
        view.safeAreaRegions = []
        context.coordinator.layer = view.layer
        return view
    }

    func updateNSView(_ view: NSHostingView<Content>, context: Context) {
        view.rootView = content
        context.coordinator.layer = view.layer
        context.coordinator.active = active && !reduceMotion
        context.coordinator.pulseIfNeeded()
    }

    /// Never takes a click from the button or row it sits in.
    private final class Host: NSHostingView<Content> {
        override func hitTest(_ point: NSPoint) -> NSView? { nil }
    }

    /// One fade down and back at a time, run again for as long as the activity lasts.
    final class Coordinator: NSObject, CAAnimationDelegate {
        weak var layer: CALayer?
        var active = false
        private var isFading = false

        func pulseIfNeeded() {
            guard active, !isFading, let layer else { return }
            let fade = CABasicAnimation(keyPath: "opacity")
            fade.fromValue = 1
            fade.toValue = VegaDesign.Motion.pulseDim
            fade.duration = VegaDesign.Motion.pulseDuration
            fade.autoreverses = true
            fade.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            fade.delegate = self
            isFading = true
            layer.add(fade, forKey: "vegaPulse")
        }

        func animationDidStop(_ animation: CAAnimation, finished: Bool) {
            isFading = false
            pulseIfNeeded()
        }
    }
}
#else
private struct VegaPulse<Content: View>: View {
    let active: Bool
    let content: Content
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        content
            .opacity(active && !reduceMotion ? VegaDesign.Motion.pulseDim : 1)
            .animation(active ? VegaDesign.Motion.pulse : VegaDesign.Motion.quick, value: active)
    }
}
#endif
