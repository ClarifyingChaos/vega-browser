// Licensed under GPL-3.0. See LICENSE.
//
//  BrowserConfig.swift
//  Vega
//
//  Created by Maciek Bagiński on 31/07/2025.
//

import SwiftUI
import WebKit
import VegaBlocker

public class BrowserConfiguration {
    public static let shared = BrowserConfiguration()
    
    private init() {}
    
    public lazy var webViewConfiguration: WKWebViewConfiguration = {
        let config = WKWebViewConfiguration()
        #if os(macOS)
        BrowserConfiguration.applyProcessPool(to: config)
        #endif

        // Use default website data store for normal browsing
        // Extensions use their own separate persistent storage managed by Apple
        config.websiteDataStore = WKWebsiteDataStore.default()

        // Configure JavaScript preferences for extension support
        let preferences = WKWebpagePreferences()
        preferences.allowsContentJavaScript = true
        config.defaultWebpagePreferences = preferences

        // Core WebKit preferences for extensions
        config.preferences.javaScriptCanOpenWindowsAutomatically = false

        // Media settings — use macOS default (no restrictions, matching Safari behavior).
        // [.audio] blocks programmatic play() for media with audio tracks, which breaks
        // YouTube autoplay since SPA navigations call play() outside user-gesture context.
        config.mediaTypesRequiringUserActionForPlayback = []
        
        // "mediaDevicesEnabled" stays unset: it crashes WebContent (sandbox-denied AudioComponentRegistrar).
        // Pages still get mic and camera from the Info.plist usage strings and device entitlements.

        // CRITICAL: Enable HTML5 Fullscreen API
        config.preferences.isElementFullscreenEnabled = true

        // Enable background media playback
        config.allowsAirPlayForMediaPlayback = true
        
        // User agent for better compatibility with Client Hints support
        config.applicationNameForUserAgent = "Version/\(PlatformUserAgent.safariVersion) Safari/605.1.15"

        // Clipboard, picture-in-picture, inline playback and the inspector are spelled differently
        // per platform; see BrowserConfig+macOS.swift and BrowserConfig+iOS.swift.
        BrowserConfiguration.applyPlatformPreferences(to: config)

        // Note: webExtensionController will be set by ExtensionManager during initialization

        // MARK: Passkey suppression
        // Pending Apple approval of com.apple.developer.web-browser.public-key-credential,
        // tell websites we don't support platform authenticators so they won't prompt for passkeys.
        // TODO: Remove this once the entitlement is granted.
        let passkeySuppress = WKUserScript(
            source: """
            // Vega Passkey Suppression
            (function() {
                if (window.PublicKeyCredential) {
                    PublicKeyCredential.isUserVerifyingPlatformAuthenticatorAvailable = function() {
                        return Promise.resolve(false);
                    };
                    if (PublicKeyCredential.isConditionalMediationAvailable) {
                        PublicKeyCredential.isConditionalMediationAvailable = function() {
                            return Promise.resolve(false);
                        };
                    }
                }
            })();
            """,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: false
        )
        config.userContentController.addUserScript(passkeySuppress)

        // FORK: slim page scrollbars, the same thickness as the sidebar's: a 6 pt pill with 3 pt of space around it, on a clear track (the space is a transparent border, so the pill stays round),
        // instead of the system's wide bar. Added at the end of the document's head so the page's own sheets come first.
        config.userContentController.addUserScript(WKUserScript(
            source: """
            // Vega slim scrollbars
            (function() {
                // !important, and an adopted sheet (which sorts after the page's own), so a site that styles its scrollbars
                // itself (Pinterest does) still gets the slim one.
                // WebKit paints a transparent corner opaque white, and the rounded window clips that square into a white
                // wedge at the bottom-right. So the corner takes the page's own colour, resampled as the page settles.
                const bg = () => {
                    for (const el of [document.body, document.documentElement]) {
                        if (!el) continue;
                        const c = getComputedStyle(el).backgroundColor;
                        if (c && c !== 'rgba(0, 0, 0, 0)' && c !== 'transparent') return c;
                    }
                    // The page's own canvas: dark for a page that sets color-scheme dark, whatever the Mac is in.
                    return 'Canvas';
                };
                // The track is painted white the same way when the Mac shows scroll bars all the time, so it gets the colour too.
                const css = () => '::-webkit-scrollbar{width:12px !important;height:12px !important;background:' + bg() + ' !important}' +
                            '::-webkit-scrollbar-track,::-webkit-scrollbar-track-piece{background:' + bg() + ' !important}' +
                            '::-webkit-scrollbar-button{display:none !important;width:0 !important;height:0 !important}' +
                            '::-webkit-scrollbar-corner{background:' + bg() + ' !important}' +
                            '::-webkit-scrollbar-thumb{background:rgba(128,128,128,.55) !important;border-radius:6px !important;border:3px solid transparent !important;background-clip:padding-box !important;min-height:34px}' +
                            '::-webkit-scrollbar-thumb:hover{background:rgba(128,128,128,.8) !important}';
                let sheet = null, style = null;
                const apply = () => {
                    if (sheet) { sheet.replaceSync(css()); return; }
                    if (style) { style.textContent = css(); return; }
                    try { sheet = new CSSStyleSheet(); sheet.replaceSync(css()); document.adoptedStyleSheets = [...document.adoptedStyleSheets, sheet]; }
                    catch (e) { sheet = null; style = document.createElement('style'); style.textContent = css(); (document.head || document.documentElement).appendChild(style); }
                };
                apply();
                document.addEventListener('DOMContentLoaded', apply);
                window.addEventListener('load', () => { apply(); setTimeout(apply, 1000); });
                window.addEventListener('resize', apply);
            })();
            """,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: false
        ))

        // FORK: pop-up ads. Ad scripts open their window on any click by making a link and clicking it from script,
        // or by calling window.open. Neither is a link you clicked: a window to another site opens only when the click
        // you made landed on a link or a button. Runs in every frame; read once, at start-up (on unless turned off).
        if (UserDefaults.standard.object(forKey: "settings.blockScriptedPopups") as? Bool) ?? true {
            config.userContentController.addUserScript(WKUserScript(
                source: """
                // Vega popup guard
                (function() {
                    if (window.__vegaPopupGuard) return;
                    Object.defineProperty(window, '__vegaPopupGuard', { value: true });
                    const bare = h => h.replace(/^www\\./, '');
                    const sameSite = url => {
                        try { const a = bare(new URL(url, location.href).hostname), b = bare(location.hostname);
                              return a === b || a.endsWith('.' + b) || b.endsWith('.' + a); } catch (e) { return true; }
                    };
                    // The last click you made, and the link it landed on, if any. A player's play button is a control too,
                    // and ad scripts ride on exactly that click, so only the link you really clicked may open elsewhere.
                    let trusted = { at: 0, href: '' };
                    // A link to another site that covers the page and shows nothing is an ad laid over the video: your click
                    // is not given to it, and it is removed so the next click reaches the page.
                    const coversPage = a => {
                        const r = a.getBoundingClientRect();
                        if (r.width * r.height < 0.3 * innerWidth * innerHeight) return false;
                        const empty = !a.textContent.trim() && !a.querySelector('img, svg, video, canvas, picture, iframe, input, button');
                        return empty || parseFloat(getComputedStyle(a).opacity) < 0.1;
                    };
                    addEventListener('click', e => {
                        if (!e.isTrusted) return;
                        const a = e.target && e.target.closest && e.target.closest('a[href]');
                        if (a && !sameSite(a.href) && coversPage(a)) { e.preventDefault(); e.stopImmediatePropagation(); a.remove(); return; }
                        trusted.at = Date.now(); trusted.href = a ? a.href : '';
                    }, true);
                    const sameHost = (x, y) => { try { return new URL(x, location.href).hostname === new URL(y, location.href).hostname; } catch (e) { return false; } };
                    // Sign-in and payment windows are opened by a button on purpose.
                    const signIn = u => { try { const t = new URL(u, location.href);
                        return /(^|\\.)(accounts\\.google|appleid\\.apple|login\\.microsoftonline|login\\.live|github|facebook|discord|auth0|okta|paypal|stripe|twitter|x|linkedin|amazon|slack|zoom)\\.(com|us)$/i.test(t.hostname)
                            || /\\/(oauth|oauth2|authorize|login|signin|sso|saml|auth|checkout|pay)(\\/|$|\\?)/i.test(t.pathname); } catch (e) { return false; } };
                    // Share buttons open the network's own share address (a tweet, a post, a pin), never an ad domain.
                    const share = u => { try { const t = new URL(u, location.href); const h = t.hostname.replace(/^www\\./, '');
                        const net = /(^|\\.)(twitter\\.com|x\\.com|facebook\\.com|linkedin\\.com|pinterest\\.[a-z.]+|reddit\\.com|tumblr\\.com|vk\\.com|t\\.me|telegram\\.me|wa\\.me|whatsapp\\.com|api\\.whatsapp\\.com|line\\.me|weibo\\.com|ok\\.ru|bsky\\.app|threads\\.net|mastodon\\.social|getpocket\\.com|flipboard\\.com|buffer\\.com|mail\\.google\\.com|outlook\\.live\\.com)$/i.test(h);
                        return net && /(share|sharer|intent|submit|post|compose|dialog|send|pin\\/create|add)/i.test(t.pathname + t.search); } catch (e) { return false; } };
                    const mayOpen = url => sameSite(url) || signIn(url) || share(url) || (Date.now() - trusted.at < 1500 && trusted.href && sameHost(url, trusted.href));
                    const opensNewWindow = a => { const t = (a.target || '').toLowerCase(); return t && t !== '_self' && t !== '_top' && t !== '_parent'; };

                    // A link clicked or "dispatched" by script, to another site, in a new window.
                    const click = HTMLAnchorElement.prototype.click;
                    HTMLAnchorElement.prototype.click = function() {
                        if (opensNewWindow(this) && !mayOpen(this.href)) return;
                        return click.apply(this, arguments);
                    };
                    const dispatch = HTMLAnchorElement.prototype.dispatchEvent;
                    HTMLAnchorElement.prototype.dispatchEvent = function(e) {
                        if (e && e.type === 'click' && !e.isTrusted && opensNewWindow(this) && !mayOpen(this.href)) return false;
                        return dispatch.apply(this, arguments);
                    };
                    document.addEventListener('click', e => {
                        if (e.isTrusted) return;
                        const a = e.target && e.target.closest && e.target.closest('a[href]');
                        if (a && opensNewWindow(a) && !mayOpen(a.href)) { e.preventDefault(); e.stopImmediatePropagation(); }
                    }, true);

                    // window.open to another site, unless it is the link you clicked or a sign-in or payment window.
                    const open = window.open;
                    window.open = function(url) {
                        if (url && !mayOpen(String(url))) return null;
                        return open.apply(this, arguments);
                    };
                })();
                """,
                injectionTime: .atDocumentStart,
                forMainFrameOnly: false
            ))
        }

        // FORK: relay-only WebRTC when the person turned it on (read once, at start-up).
        if UserDefaults.standard.bool(forKey: "settings.webRTCRelayOnly") {
            config.userContentController.addUserScript(WKUserScript(
                source: """
                // Vega WebRTC relay
                (function() {
                    const Native = window.RTCPeerConnection || window.webkitRTCPeerConnection;
                    if (!Native) return;
                    function Relay(configuration, constraints) {
                        const c = Object.assign({}, configuration || {});
                        c.iceTransportPolicy = 'relay';
                        return new Native(c, constraints);
                    }
                    Relay.prototype = Native.prototype;
                    Object.setPrototypeOf(Relay, Native);
                    window.RTCPeerConnection = Relay;
                    if (window.webkitRTCPeerConnection) window.webkitRTCPeerConnection = Relay;
                })();
                """,
                injectionTime: .atDocumentStart,
                forMainFrameOnly: false
            ))
        }

        return config
    }()

    /// Optional hook for ContentBlockerManager to apply rule lists to new controllers.
    public var contentRuleListApplicator: ((WKUserContentController) -> Void)?

    // MARK: - Fresh User Content Controller
    // Creates a fresh WKUserContentController but preserves Vega's own shared
    // user scripts. This avoids cross-tab handler conflicts while keeping
    // scripts that must be present on every tab.
    //
    // Only Vega-owned scripts are copied. WKWebExtensionController injects its
    // content scripts into every new controller itself, so copying them here as
    // well would hand each new tab two of each. See WKUserScript+VegaOwned.
    public func freshUserContentController() -> WKUserContentController {
        let controller = WKUserContentController()
        for script in webViewConfiguration.userContentController.userScripts.vegaOwned {
            controller.addUserScript(script)
        }
        // The page's top strip drags the window only over empty space, not over text.
        MainActor.assumeIsolated { TitleBandProbe.install(in: controller) }
        // Apply content blocker rule lists if available
        contentRuleListApplicator?(controller)
        return controller
    }

    // MARK: - Cache-Optimized Configuration
    // Derives from shared config to preserve process pool + extension controller
    public func cacheOptimizedWebViewConfiguration() -> WKWebViewConfiguration {
        let config = webViewConfiguration.copy() as! WKWebViewConfiguration
        config.userContentController = freshUserContentController()
        return config
    }

    // MARK: - Profile-Aware Configurations
    // Derive from the shared config so extension controller + process pool are inherited
    @MainActor
    public func webViewConfiguration(for profile: Profile) -> WKWebViewConfiguration {
        let config = webViewConfiguration.copy() as! WKWebViewConfiguration

        // Fresh UCC per tab to avoid cross-tab handler conflicts (preserves shared scripts)
        config.userContentController = freshUserContentController()

        // Use the profile's website data store for isolation
        // Private pages keep the controller; WebKit runs only extensions with
        // `hasAccessToPrivateData` in a non-persistent store's pages.
        config.websiteDataStore = profile.dataStore
        // A tab waking from sleep gets back any sign-in cookie the store lost while nothing was using it.
        profile.reapplyMissingSessionCookies()

        return config
    }

    // MARK: - Chrome Web Store Integration
    
    /// Get the Web Store injector script
    public static func webStoreInjectorScript() -> WKUserScript? {
        guard let scriptPath = Bundle.main.path(forResource: "WebStoreInjector", ofType: "js"),
              let scriptSource = try? String(contentsOfFile: scriptPath, encoding: .utf8) else {
            return nil
        }
        
        return WKUserScript(
            source: scriptSource,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: true
        )
    }
}
