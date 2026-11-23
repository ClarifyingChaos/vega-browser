// Licensed under GPL-3.0. See LICENSE.
//
//  TitleBandProbe.swift
//  VegaWeb
//
//  FORK: the top strip of a page drags the window, like Arc's, but only over empty space. Many sites show an arrow
//  cursor over their text, so the cursor alone can't tell a drag of the window from the start of a text selection. This
//  small script, in its own world, tells the native side whether there is selectable text under the pointer while it
//  is in that strip, so selecting text there selects it and never moves the window.
//

import ObjectiveC
import WebKit

public extension WKWebView {
    private static var overTextKey: UInt8 = 0

    /// True while the pointer, in the page's top strip, is over text a press could start selecting.
    var pointerOverTextInTitleBand: Bool {
        get { (objc_getAssociatedObject(self, &Self.overTextKey) as? Bool) ?? false }
        set { objc_setAssociatedObject(self, &Self.overTextKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }
}

enum TitleBandProbe {
    private static let handlerName = "vegaTitleBandText"
    private static let world = WKContentWorld.world(name: "VegaTitleBandProbe")

    /// Starts with "// Vega" so it survives a rebuild of a view's scripts (see WKUserScript+VegaOwned).
    private static let source = #"""
    // Vega Title Band Probe
    (function () {
      const STRIP = 80, post = (v) => window.webkit.messageHandlers.vegaTitleBandText.postMessage(v);
      let last = false, at = 0;
      const set = (v) => { if (v !== last) { last = v; post(v); } };
      // Over the glyphs themselves, not just inside a block that holds text: blank space beside a heading still drags.
      const textAt = (x, y) => {
        const caret = document.caretRangeFromPoint ? document.caretRangeFromPoint(x, y) : null;
        const node = caret && caret.startContainer;
        if (!node || node.nodeType !== 3 || !node.textContent.trim() || !node.parentElement) return false;
        const cs = getComputedStyle(node.parentElement);
        if (cs.webkitUserSelect === 'none' || cs.userSelect === 'none') return false;
        const range = document.createRange();
        range.selectNodeContents(node);
        for (const q of range.getClientRects()) {
          if (x >= q.left - 2 && x <= q.right + 2 && y >= q.top - 2 && y <= q.bottom + 2) return true;
        }
        return false;
      };
      addEventListener('mousemove', (e) => {
        if (e.clientY > STRIP) return set(false);
        const now = performance.now();
        if (now - at < 50) return;   // a probe every 50 ms at most, and only while the pointer is in the strip
        at = now;
        set(textAt(e.clientX, e.clientY));
      }, { capture: true, passive: true });
      document.addEventListener('mouseleave', () => set(false), { capture: true, passive: true });
    })();
    """#

    private final class Handler: NSObject, WKScriptMessageHandler {
        static let shared = Handler()
        func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
            message.webView?.pointerOverTextInTitleBand = (message.body as? Bool) ?? false
        }
    }

    @MainActor
    static func install(in controller: WKUserContentController) {
        controller.removeScriptMessageHandler(forName: handlerName, contentWorld: world)
        controller.add(Handler.shared, contentWorld: world, name: handlerName)
        controller.addUserScript(WKUserScript(source: source, injectionTime: .atDocumentStart, forMainFrameOnly: true, in: world))
    }
}
