// Licensed under GPL-3.0 with the App Store exception in LICENSE-EXCEPTION.md.
//
//  VegaWebView.swift
//  VegaiOS
//

import WebKit
import VegaWeb

/// The session's view on iOS. FocusableWKWebView's job on macOS is focus and the context menu;
/// neither exists here, so this only carries the back-reference the package expects.
@MainActor
final class VegaWebView: WKWebView, SessionWebView {
    weak var owningSession: PageSession?
    var contextMenuBridge: WebContextMenuBridge?
    func contextMenuPayloadDidUpdate(_ payload: WebContextMenuPayload?) {}
}
