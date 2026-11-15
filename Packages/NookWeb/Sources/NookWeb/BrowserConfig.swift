// Licensed under GPL-3.0. See LICENSE.
//
//  BrowserConfig.swift
//  Nook
//
//  Created by Maciek Bagiński on 31/07/2025.
//

import SwiftUI
import WebKit
import NookBlocker

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
            // Nook Passkey Suppression
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

        // FORK: pop-up ads. Ad scripts open their window on any click by making a link and clicking it from script,
        // or by calling window.open. Neither is a link you clicked: a window to another site opens only when the click
        // you made landed on a link or a button. Runs in every frame; read once, at start-up (on unless turned off).
        if (UserDefaults.standard.object(forKey: "settings.blockScriptedPopups") as? Bool) ?? true {
            config.userContentController.addUserScript(WKUserScript(
                source: """
                // Nook popup guard
                (function() {
                    if (window.__vegaPopupGuard) return;
                    Object.defineProperty(window, '__vegaPopupGuard', { value: true });
                    const bare = h => h.replace(/^www\\./, '');
                    const sameSite = url => {
                        try { const a = bare(new URL(url, location.href).hostname), b = bare(location.hostname);
                              return a === b || a.endsWith('.' + b) || b.endsWith('.' + a); } catch (e) { return true; }
                    };
                    // The last click you made, and whether it landed on a link or a button.
                    let trusted = { at: 0, control: false };
                    addEventListener('click', e => {
                        if (!e.isTrusted) return;
                        const t = e.target;
                        trusted = { at: Date.now(), control: !!(t && t.closest && t.closest('a, button, [role=button], input[type=button], input[type=submit]')) };
                    }, true);
                    const youClickedAControl = () => Date.now() - trusted.at < 1500 && trusted.control;
                    const opensNewWindow = a => { const t = (a.target || '').toLowerCase(); return t && t !== '_self' && t !== '_top' && t !== '_parent'; };

                    // A link clicked or "dispatched" by script, to another site, in a new window.
                    const click = HTMLAnchorElement.prototype.click;
                    HTMLAnchorElement.prototype.click = function() {
                        if (opensNewWindow(this) && !sameSite(this.href) && !youClickedAControl()) return;
                        return click.apply(this, arguments);
                    };
                    const dispatch = HTMLAnchorElement.prototype.dispatchEvent;
                    HTMLAnchorElement.prototype.dispatchEvent = function(e) {
                        if (e && e.type === 'click' && !e.isTrusted && opensNewWindow(this) && !sameSite(this.href) && !youClickedAControl()) return false;
                        return dispatch.apply(this, arguments);
                    };
                    document.addEventListener('click', e => {
                        if (e.isTrusted) return;
                        const a = e.target && e.target.closest && e.target.closest('a[href]');
                        if (a && opensNewWindow(a) && !sameSite(a.href) && !youClickedAControl()) { e.preventDefault(); e.stopImmediatePropagation(); }
                    }, true);

                    // window.open to another site from a click that was not on a link or a button.
                    const open = window.open;
                    window.open = function(url) {
                        if (url && !sameSite(url) && !youClickedAControl()) return null;
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
                // Nook WebRTC relay
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
    // Creates a fresh WKUserContentController but preserves Nook's own shared
    // user scripts. This avoids cross-tab handler conflicts while keeping
    // scripts that must be present on every tab.
    //
    // Only Nook-owned scripts are copied. WKWebExtensionController injects its
    // content scripts into every new controller itself, so copying them here as
    // well would hand each new tab two of each. See WKUserScript+NookOwned.
    public func freshUserContentController() -> WKUserContentController {
        let controller = WKUserContentController()
        for script in webViewConfiguration.userContentController.userScripts.nookOwned {
            controller.addUserScript(script)
        }
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
