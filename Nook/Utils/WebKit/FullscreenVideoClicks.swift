// Licensed under GPL-3.0. See LICENSE.
//
//  FullscreenVideoClicks.swift
//  Nook
//
//  FORK: when a fullscreen video pauses, WebKit lays macOS's Live Text view over it. It took every click, so Play
//  could not be pressed and right-click offered only Save and Copy Image. The view stays (turning WebKit's feature
//  off makes the page's process crash when it asks for it anyway) but in a fullscreen window it takes no clicks.
//

import AppKit

enum FullscreenVideoClicks {
    private static var installed = false

    static func install() {
        guard !installed else { return }
        dlopen("/System/Library/PrivateFrameworks/VisionKitCore.framework/VisionKitCore", RTLD_LAZY)
        let selector = #selector(NSView.hitTest(_:))
        guard let overlay = NSClassFromString("VKCImageAnalysisOverlayView"),
              let method = class_getInstanceMethod(overlay, selector) else { return }
        installed = true
        typealias HitTest = @convention(c) (NSView, Selector, NSPoint) -> NSView?
        let original = unsafeBitCast(method_getImplementation(method), to: HitTest.self)
        let replacement: @convention(block) (NSView, NSPoint) -> NSView? = { view, point in
            MainActor.assumeIsolated {
                takesNoClicks(in: view.window) ? nil : original(view, selector, point)
            }
        }
        // Adds the method to this class if it only inherits it, so NSView's own is never changed.
        class_replaceMethod(overlay, selector, imp_implementationWithBlock(replacement), method_getTypeEncoding(method))
    }

    /// WebKit's element-fullscreen window (`WebCoreFullScreenWindow`). Live Text elsewhere keeps working.
    @MainActor static func takesNoClicks(in window: NSWindow?) -> Bool {
        window.map { String(describing: type(of: $0)).contains("FullScreenWindow") } ?? false
    }
}
