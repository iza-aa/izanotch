//
//  WebWorkspaceLoginWindowController.swift
//  izaNotch (Izanotchy)
//
//  Pop-out authentication window for Web Workspace (TASK-046 1Password Pattern).
//  Solves keyboard focus failure over fullscreen Spaces.
//

import AppKit
import WebKit

@MainActor
public final class WebWorkspaceLoginWindowController: NSObject, NSWindowDelegate {
    public static let shared = WebWorkspaceLoginWindowController()

    public private(set) var window: NSWindow?
    public private(set) var isLoginWindowOpen: Bool = false

    private weak var previousSuperview: NSView?
    private var onCompletion: ((Bool) -> Void)?

    private override init() {
        super.init()
    }

    /// Opens the standalone login window hosting the shared WKWebView.
    public func presentLoginWindow(
        with webView: WKWebView,
        title: String = "Login — Web Workspace",
        onLoginComplete: @escaping (Bool) -> Void
    ) {
        self.onCompletion = onLoginComplete
        self.isLoginWindowOpen = true
        self.previousSuperview = webView.superview

        // Detach webView from its current view hierarchy
        webView.removeFromSuperview()

        if window == nil {
            let win = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 480, height: 640),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )
            win.title = title
            win.isReleasedWhenClosed = false
            win.delegate = self
            // Allow window to appear on top of any fullscreen Space
            win.collectionBehavior = [.fullScreenAuxiliary, .participatesInCycle]
            win.level = .floating
            self.window = win
        }

        guard let win = self.window else { return }
        win.title = title

        // Mount the webView into window contentView
        webView.translatesAutoresizingMaskIntoConstraints = true
        webView.autoresizingMask = [.width, .height]
        webView.frame = win.contentView?.bounds ?? NSRect(x: 0, y: 0, width: 480, height: 640)
        win.contentView = webView

        win.center()
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        let shifted = win.makeFirstResponder(webView)
        ClickyLogger.info("[LOGIN_WINDOW]", "Opened standalone login window (~480x640): firstResponder=\(shifted), window='\(win.title)'")
    }

    /// Dismisses the login window and restores the webView to its original container.
    public func dismissLoginWindow() {
        guard isLoginWindowOpen else { return }
        self.isLoginWindowOpen = false

        if let win = self.window {
            win.contentView = nil
            win.orderOut(nil)
        }

        // Restore webView back to container
        let targetContainer = previousSuperview ?? CompanionVMViewportController.shared.viewportContainer
        if let target = targetContainer, let wv = CompanionVMViewportController.shared.webView {
            wv.removeFromSuperview()
            wv.translatesAutoresizingMaskIntoConstraints = false
            target.addSubview(wv)
            NSLayoutConstraint.activate([
                wv.leadingAnchor.constraint(equalTo: target.leadingAnchor),
                wv.trailingAnchor.constraint(equalTo: target.trailingAnchor),
                wv.topAnchor.constraint(equalTo: target.topAnchor),
                wv.bottomAnchor.constraint(equalTo: target.bottomAnchor)
            ])
            ClickyLogger.info("[LOGIN_WINDOW]", "Restored WKWebView back to HomeSpace container.")
        }

        ClickyLogger.info("[LOGIN_WINDOW]", "Closed login window.")
    }

    // MARK: - NSWindowDelegate

    public func windowDidBecomeKey(_ notification: Notification) {
        guard let win = self.window, let wv = CompanionVMViewportController.shared.webView else { return }
        let shifted = win.makeFirstResponder(wv)
        ClickyLogger.info("[LOGIN_WINDOW]", "windowDidBecomeKey: First responder shifted to WKWebView: \(shifted)")
    }

    public func windowWillClose(_ notification: Notification) {
        if isLoginWindowOpen {
            dismissLoginWindow()
            onCompletion?(false)
            onCompletion = nil
        }
    }
}
