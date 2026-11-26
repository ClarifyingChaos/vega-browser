// Live Text over a paused fullscreen video takes no clicks; elsewhere it is left as it was.
// swiftc -parse-as-library Nook/Utils/WebKit/FullscreenVideoClicks.swift scripts/tests/FullscreenVideoClicksCheck.swift -o /tmp/fsclicks && /tmp/fsclicks

import AppKit

final class StandInFullScreenWindow: NSWindow {}

@main
@MainActor
struct FullscreenVideoClicksCheck {
    static func main() {
        _ = NSApplication.shared
        precondition(FullscreenVideoClicks.takesNoClicks(in: StandInFullScreenWindow()))
        precondition(!FullscreenVideoClicks.takesNoClicks(in: NSWindow()))
        precondition(!FullscreenVideoClicks.takesNoClicks(in: nil))

        dlopen("/System/Library/PrivateFrameworks/VisionKitCore.framework/VisionKitCore", RTLD_LAZY)
        guard let overlay = NSClassFromString("VKImageAnalysisOverlayView") as? NSView.Type else {
            // A build machine's macOS may not carry it; on a person's Mac its absence is news.
            if ProcessInfo.processInfo.environment["CI"] != nil { return print("skip: no Live Text view here") }
            preconditionFailure("macOS no longer has the Live Text view; check how fullscreen video behaves now")
        }
        let rect = NSRect(x: 0, y: 0, width: 200, height: 200)
        func window<W: NSWindow>(_ type: W.Type) -> W { W(contentRect: rect, styleMask: .borderless, backing: .buffered, defer: true) }
        /// What a click in the middle lands on, with the Live Text view in front.
        func clicked(in window: NSWindow) -> (hit: NSView?, view: NSView) {
            let view = overlay.init(frame: rect)
            view.addSubview(NSView(frame: view.bounds))
            window.contentView = NSView(frame: rect)
            window.contentView?.addSubview(view)
            return (window.contentView?.hitTest(NSPoint(x: 100, y: 100)), view)
        }
        func kind(_ result: (hit: NSView?, view: NSView)) -> String {
            guard let hit = result.hit else { return "nothing" }
            return hit === result.view ? "overlay" : hit.isDescendant(of: result.view) ? "inside" : "behind"
        }
        let ordinary = window(NSWindow.self)
        let before = kind(clicked(in: ordinary))
        FullscreenVideoClicks.install()
        FullscreenVideoClicks.install()
        precondition(kind(clicked(in: window(StandInFullScreenWindow.self))) == "behind", "the click passes through in fullscreen")
        precondition(kind(clicked(in: ordinary)) == before, "Live Text elsewhere behaves as before: \(before)")
        print("FullscreenVideoClicksCheck passed")
    }
}
