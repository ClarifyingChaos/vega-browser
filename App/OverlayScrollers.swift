// Licensed under GPL-3.0. See LICENSE.
//
//  OverlayScrollers.swift
//  Nook
//
//  FORK: a Mac set to always show scroll bars draws the wide "legacy" bar, a strip that takes a slice of the
//  window's right edge. Every scroll view that joins a window of Vega gets the slim overlay scroller instead, the
//  one that appears while scrolling, as the sidebar and the history page already show. Web pages keep their own.
//

import AppKit
import ObjectiveC

enum OverlayScrollers {
    /// Call once at launch, before the first window.
    static func install() {
        let cls = NSScrollView.self
        let original = #selector(NSView.viewDidMoveToWindow)
        let replacement = #selector(NSScrollView.vega_viewDidMoveToWindow)
        guard let originalMethod = class_getInstanceMethod(cls, original),
              let replacementMethod = class_getInstanceMethod(cls, replacement) else { return }
        // NSScrollView may only inherit the method: add ours to the class first so NSView's is left alone.
        if class_addMethod(cls, original, method_getImplementation(replacementMethod), method_getTypeEncoding(replacementMethod)) {
            class_replaceMethod(cls, replacement, method_getImplementation(originalMethod), method_getTypeEncoding(originalMethod))
        } else {
            method_exchangeImplementations(originalMethod, replacementMethod)
        }
    }
}

extension NSScrollView {
    @objc fileprivate func vega_viewDidMoveToWindow() {
        vega_viewDidMoveToWindow()   // the original, after the exchange
        if window != nil, hasVerticalScroller, scrollerStyle != .overlay { scrollerStyle = .overlay }
    }
}
