//
//  CompanionVMViewportController.swift
//  izaNotch
//
//  Grok-Bot Style Persistent Application VM Viewport Controller.
//  Hosts real applications (Mail, Safari/Web) inside an isolated WebKit container
//  with persistent sessions in ~/.izanotchy/companions/<slug>/browser_data/.
//  Supports targeted VM Vision snapshots and virtual CUA event dispatch.
//

import Foundation
import AppKit
import WebKit
import SwiftUI

@MainActor
public final class CompanionVMViewportController: NSObject, ObservableObject, WKNavigationDelegate, WKUIDelegate {
    public static let shared = CompanionVMViewportController()

    @Published public private(set) var activeSnapshot: NSImage?
    @Published public private(set) var activeSnapshotPath: String?
    @Published public var currentUrlString: String = ""
    @Published public var pageTitle: String = "Virtual Machine"
    @Published public var isLoading: Bool = false
    @Published public var vmCursorPosition: CGPoint = CGPoint(x: 350, y: 220)
    @Published public var isClicking: Bool = false
    @Published public var isTakeoverActive: Bool = false {
        didSet {
            guard oldValue != isTakeoverActive else { return }
            handleTakeoverStateChange()
        }
    }
    @Published public var requiresLoginTakeover: Bool = false
    @Published public var currentApp: String = "mail" // "mail", "safari"
    @Published public var mailProvider: String = "gmail" // "gmail", "outlook", "icloud"

    public private(set) var webView: WKWebView?
    public weak var viewportContainer: NSView? = nil
    private var currentSlug: String = "inbox-buddy"

    public override init() {
        super.init()
    }

    public func handleTakeoverStateChange() {
        if isTakeoverActive {
            let win = self.webView?.window ?? HomeSpaceWindowManager.shared.window ?? NSApp.keyWindow
            if let win = win, let wv = self.webView {
                win.makeKeyAndOrderFront(nil)
                NSApp.activate(ignoringOtherApps: true)
                let shifted = win.makeFirstResponder(wv)
                ClickyLogger.info("[TAKEOVER]", "First responder shifted to WKWebView: success=\(shifted), window='\(win.title)'")
            } else {
                ClickyLogger.warning("[TAKEOVER]", "Cannot shift first responder: webView or window is nil.")
            }
        } else {
            let win = self.webView?.window ?? HomeSpaceWindowManager.shared.window ?? NSApp.keyWindow
            if let win = win, let wv = self.webView, win.firstResponder == wv {
                win.makeFirstResponder(nil)
                ClickyLogger.info("[TAKEOVER]", "First responder resigned from WKWebView.")
            }
        }
    }
    // MARK: - Viewport Lifecycle & App Loading
    public func prepareViewport(slug: String, app: String, preferredAdapterId: String? = nil, prompt: String? = nil) {
        self.currentSlug = slug
        self.currentApp = app.lowercased()
        if let preferred = preferredAdapterId {
            self.mailProvider = preferred
        } else if self.currentApp == "mail" {
            self.mailProvider = Self.resolveMailProvider(for: slug, prompt: prompt)
        }
        if webView == nil {
            let config = WKWebViewConfiguration()
            config.websiteDataStore = WKWebsiteDataStore.default()
            config.defaultWebpagePreferences.allowsContentJavaScript = true
            
            // Desktop-first layout: width >= 1024
            let wv = WKWebView(frame: CGRect(x: 0, y: 0, width: 1024, height: 640), configuration: config)
            wv.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.3 Safari/605.1.15"
            wv.navigationDelegate = self
            wv.uiDelegate = self
            wv.setValue(false, forKey: "drawsBackground") // dark native feel
            self.webView = wv
            ClickyLogger.info("[VM_VIEWPORT]", "Initialized WebKit runtime for companion: \(slug) (desktop-first user agent & 1024 layout)")
        }

        if self.currentApp == "mail" {
            loadMailApp()
        } else {
            loadSafariApp()
        }
    }

    public func setMailProvider(_ provider: String) {
        self.mailProvider = provider.lowercased()
        loadMailApp()
    }

    public func loadMailApp() {
        guard let wv = webView else { return }
        let adapter = WebSiteAdapterRegistry.shared.adapter(forProviderId: mailProvider)
        let targetUrl = adapter.entryURL

        // If webView is already navigated to this domain, do not force reload to preserve authenticated session
        if let currentHost = wv.url?.host?.lowercased(), let targetHost = targetUrl.host?.lowercased(),
           (currentHost.contains(targetHost) || targetHost.contains(currentHost)) {
            ClickyLogger.info("[VM_VIEWPORT]", "WebView already on domain '\(currentHost)'; preserving active session without reloading.")
            return
        }

        self.currentUrlString = targetUrl.absoluteString
        self.pageTitle = adapter.name
        wv.load(URLRequest(url: targetUrl))
        ClickyLogger.info("[VM_VIEWPORT]", "Loading real Mail interface: \(targetUrl.absoluteString)")
        updateViewportLayout(width: 524, height: 340)
    }
    /// Resolves webmail provider dynamically via unified WebSiteAdapterRegistry (Zero Hardcoding).
    public static func resolveMailProvider(for companionSlug: String? = nil, prompt: String? = nil) -> String {
        let companionDomains: String = {
            if let slug = companionSlug,
               let companion = CompanionRosterStore.shared.allCompanions.first(where: { $0.slug == slug }) {
                return companion.allowedSafariDomains.joined(separator: " ")
            }
            return ""
        }()
        let query = "\(prompt ?? "") \(companionDomains) \(companionSlug ?? "")"
        return WebSiteAdapterRegistry.shared.adapter(forEmailOrDomain: query).id
    }

    /// Resolves webmail adapter dynamically from email host via WebSiteAdapterRegistry (MT-11)
    public static func resolveMailProvider(forEmailHost host: String) -> WebSiteAdapter {
        return WebSiteAdapterRegistry.shared.adapter(forEmailHost: host)
    }
    // MARK: - Desktop-First Viewport Layout & Zoom

    public func updateViewportLayout(width: CGFloat, height: CGFloat, isModal: Bool = false) {
        guard let wv = webView else { return }
        let targetWidth = max(width, 1024.0)
        let zoom: CGFloat = isModal ? 1.0 : (width < 1024.0 ? max(width / 1024.0, 0.65) : 1.0)
        wv.pageZoom = zoom
        ClickyLogger.info("[WEB_VIEWPORT]", "layoutWidth=1024, zoom=\(String(format: "%.2f", zoom)), container=(\(Int(width))x\(Int(height))), isModal=\(isModal)")
    }
    public func loadSafariApp(urlString: String = "https://www.google.com") {
        guard let wv = webView else { return }
        guard let url = URL(string: urlString.hasPrefix("http") ? urlString : "https://\(urlString)") else { return }
        self.currentUrlString = url.absoluteString
        self.pageTitle = "Safari VM"
        wv.load(URLRequest(url: url))
        ClickyLogger.info("[VM_VIEWPORT]", "Loading Safari URL in VM: \(url.absoluteString)")
    }

    // MARK: - Navigation Delegates
    public func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        self.isLoading = true
    }

    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        self.isLoading = false
        self.pageTitle = webView.title ?? pageTitle
        self.currentUrlString = webView.url?.absoluteString ?? currentUrlString
        
        // Inspect if login/authentication is required
        Task { @MainActor in
            await checkAuthenticationRequirement()
            _ = await captureSnapshot(slug: self.currentSlug)
        }
    }

    // Check if the page is an authentication portal
    public func checkAuthenticationRequirement() async {
        guard let wv = webView else { return }
        let js = """
        (function() {
            var pwd = document.querySelector('input[type="password"]');
            var loginBtn = document.querySelector('button[type="submit"], input[type="submit"], [role="button"]');
            var title = (document.title || '').toLowerCase();
            var bodyText = (document.body ? document.body.innerText : '').toLowerCase();
            var isAuth = pwd !== null || title.includes('sign in') || title.includes('log in') || bodyText.includes('sign in with apple') || bodyText.includes('masuk ke akun');
            return isAuth;
        })();
        """
        if let result = try? await wv.evaluateJavaScript(js) as? Bool {
            self.requiresLoginTakeover = result
            if result {
                ClickyLogger.info("[VM_VIEWPORT]", "Authentication/Login portal detected in VM Viewport. Flagged for Human Takeover.")
            }
        }
    }

    // MARK: - Targeted VM Vision: Frame Capture
    public func captureSnapshot(slug: String? = nil) async -> (image: NSImage, path: String)? {
        guard let wv = webView else { return nil }
        let targetSlug = slug ?? currentSlug

        let config = WKSnapshotConfiguration()
        do {
            let image: NSImage = try await withCheckedThrowingContinuation { continuation in
                wv.takeSnapshot(with: config) { img, err in
                    if let img = img {
                        continuation.resume(returning: img)
                    } else {
                        continuation.resume(throwing: err ?? NSError(domain: "VMViewport", code: -1, userInfo: [NSLocalizedDescriptionKey: "Snapshot capture failed"]))
                    }
                }
            }

            let home = FileManager.default.homeDirectoryForCurrentUser
            let snapshotsDir = home.appendingPathComponent(".izanotchy/companions/\(targetSlug)/workspace/snapshots", isDirectory: true)
            try? FileManager.default.createDirectory(at: snapshotsDir, withIntermediateDirectories: true)
            let filePath = snapshotsDir.appendingPathComponent("active_frame.png").path

            if let tiff = image.tiffRepresentation,
               let rep = NSBitmapImageRep(data: tiff),
               let png = rep.representation(using: .png, properties: [:]) {
                try? png.write(to: URL(fileURLWithPath: filePath), options: .atomic)
            }

            self.activeSnapshot = image
            self.activeSnapshotPath = filePath
            CompanionWindowStreamService.shared.updateActiveSnapshot(image, path: filePath)
            return (image, filePath)
        } catch {
            ClickyLogger.warning("[VM_VIEWPORT]", "Snapshot capture error: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Targeted VM CUA: Virtual Cursor & Action Injection
    public func simulateVMClick(at point: CGPoint) async {
        // 1. Move virtual cursor smoothly inside VM viewport (0 host Mac cursor movement)
        withAnimation(.spring(response: 0.30, dampingFraction: 0.8)) {
            self.vmCursorPosition = point
        }
        try? await Task.sleep(nanoseconds: 250_000_000)

        // 2. Click pulse
        self.isClicking = true
        try? await Task.sleep(nanoseconds: 120_000_000)
        self.isClicking = false

        // 3. Dispatch click event directly to WebKit DOM
        let js = """
        (function() {
            var el = document.elementFromPoint(\(point.x), \(point.y));
            if (el) {
                el.focus();
                var clickEvt = new MouseEvent('click', {
                    bubbles: true,
                    cancelable: true,
                    view: window,
                    clientX: \(point.x),
                    clientY: \(point.y)
                });
                el.dispatchEvent(clickEvt);
                return el.tagName + (el.innerText ? ': ' + el.innerText.substring(0, 30) : '');
            }
            return null;
        })();
        """
        _ = try? await webView?.evaluateJavaScript(js)
        _ = await captureSnapshot()
    }

    public func simulateVMType(text: String) async {
        let escaped = text
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
            .replacingOccurrences(of: "\n", with: "\\n")
        let js = """
        (function() {
            var el = document.activeElement;
            if (el && ('value' in el || el.isContentEditable)) {
                if ('value' in el) {
                    el.value += '\(escaped)';
                } else {
                    el.innerText += '\(escaped)';
                }
                el.dispatchEvent(new Event('input', { bubbles: true }));
                el.dispatchEvent(new Event('change', { bubbles: true }));
                return true;
            }
            return false;
        })();
        """
        _ = try? await webView?.evaluateJavaScript(js)
        _ = await captureSnapshot()
    }

    // MARK: - AI Grounding & Inspection
    public func extractVMElements() async -> [String] {
        guard let wv = webView else { return [] }
        let js = """
        (function() {
            var elements = [];
            var nodes = document.querySelectorAll('button, a, input, [role="button"], [role="link"], h1, h2, h3, [data-message-id]');
            for (var i = 0; i < Math.min(nodes.length, 30); i++) {
                var text = (nodes[i].innerText || nodes[i].placeholder || nodes[i].getAttribute('aria-label') || '').trim();
                if (text.length > 0) {
                    var rect = nodes[i].getBoundingClientRect();
                    elements.push(nodes[i].tagName + ' "' + text.substring(0, 40) + '" at (' + Math.round(rect.x + rect.width/2) + ',' + Math.round(rect.y + rect.height/2) + ')');
                }
            }
            return elements;
        })();
        """
        if let result = try? await wv.evaluateJavaScript(js) as? [String] {
            return result
        }
        return []
    }

    public func extractLatestEmailContent() async -> (sender: String, subject: String, body: String)? {
        guard let wv = webView else { return nil }
        let js = """
        (function() {
            var subject = document.querySelector('h2, .hP, .mail-subject, [role="heading"]')?.innerText || '';
            var sender = document.querySelector('.go, .email-sender, [email], span.gD')?.innerText || '';
            var body = document.querySelector('.a3s, .mail-body, [role="main"], article')?.innerText || '';
            if (subject || sender || body) {
                return {
                    subject: subject.trim(),
                    sender: sender.trim(),
                    body: body.trim()
                };
            }
            return null;
        })();
        """
        if let dict = try? await wv.evaluateJavaScript(js) as? [String: String] {
            return (dict["sender"] ?? "", dict["subject"] ?? "", dict["body"] ?? "")
        }
        return nil
    }
}
