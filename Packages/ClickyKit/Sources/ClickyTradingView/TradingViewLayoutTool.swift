import ClickyPlatform
import ClickyReasoning
import ClickyCUA
import ClickyFoundation
//
//  TradingViewLayoutTool.swift
//  boringNotch
//
//  Modular TradingView Workspace & Layout Tool
//  Handles window maximization, sidebar toggle (Option+W), modal dismissal, and canvas geometry.
//  Reusable across multiple companions (Futures Scout, Research Buddy, Clicky, etc.)
//

import AppKit
import ApplicationServices
import Carbon.HIToolbox
import Foundation

@MainActor
public final class TradingViewLayoutTool {
    public static let shared = TradingViewLayoutTool()

    private init() {}

    // MARK: - Workspace & Window Maximization

    @discardableResult
    public func maximizeWindow() async -> Bool {
        ClickyLogger.info("[TRADINGVIEW_LAYOUT]", "Maximizing TradingView window to fill visible desktop")
        guard let app = await TradingViewInputSupport.activateTradingView() else { return false }
        try? await Task.sleep(for: .milliseconds(150))

        var didMaximize = false
        if let screen = NSScreen.main {
            let vf = screen.visibleFrame

            // Strategy 1: Native Accessibility API (kAXPositionAttribute & kAXSizeAttribute)
            let pid = app.processIdentifier
            let appElement = AXUIElementCreateApplication(pid)
            var windowListRef: CFTypeRef?
            if AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowListRef) == .success,
               let windows = windowListRef as? [AXUIElement],
               let mainWindow = windows.first {
                var pos = CGPoint(x: vf.origin.x, y: screen.frame.height - vf.maxY)
                if let posVal = AXValueCreate(.cgPoint, &pos) {
                    AXUIElementSetAttributeValue(mainWindow, kAXPositionAttribute as CFString, posVal)
                }
                var sz = CGSize(width: vf.width, height: vf.height)
                if let szVal = AXValueCreate(.cgSize, &sz) {
                    let err = AXUIElementSetAttributeValue(mainWindow, kAXSizeAttribute as CFString, szVal)
                    if err == .success {
                        didMaximize = true
                        ClickyLogger.success("[TRADINGVIEW_LAYOUT]", "Window maximized via AXUIElement to \(Int(vf.width))x\(Int(vf.height))")
                    }
                }
            }

            // Strategy 2: Titlebar double-click / Option-click green zoom button if AX write didn't resize
            if !didMaximize, let bounds = TradingViewInputSupport.getTradingViewWindowBounds(), bounds.width < vf.width * 0.95 {
                // Option-click green zoom button to zoom to full screen (macOS standard zoom)
                let greenButtonPoint = CGPoint(x: bounds.origin.x + 46, y: bounds.origin.y + 14)
                TradingViewInputSupport.moveMouseSmoothly(to: greenButtonPoint)
                try? await Task.sleep(for: .milliseconds(50))
                TradingViewInputSupport.pressKey(CGKeyCode(kVK_Option), flags: [.maskAlternate])
                TradingViewInputSupport.clickMouse(at: greenButtonPoint)
                TradingViewInputSupport.pressKey(CGKeyCode(kVK_Option), flags: [])
                didMaximize = true
                ClickyLogger.info("[TRADINGVIEW_LAYOUT]", "Triggered macOS zoom via Option+Click on green button")
            }

            // Strategy 3: AppleScript System Events fallback
            if !didMaximize {
                let script = """
                tell application "System Events"
                    tell process "TradingView"
                        set frontmost to true
                        try
                            set position of window 1 to {\(Int(vf.origin.x)), \(Int(screen.frame.height - vf.maxY))}
                            set size of window 1 to {\(Int(vf.width)), \(Int(vf.height))}
                        end try
                    end tell
                end tell
                """
                if let appleScript = NSAppleScript(source: script) {
                    var err: NSDictionary?
                    appleScript.executeAndReturnError(&err)
                    if err == nil {
                        didMaximize = true
                        ClickyLogger.success("[TRADINGVIEW_LAYOUT]", "TradingView window resized via AppleScript to \(Int(vf.width))x\(Int(vf.height))")
                    }
                }
            }
        }

        try? await Task.sleep(for: .milliseconds(250))
        await resetChartScale()
        return didMaximize
    }

    // MARK: - Factual Accessibility Inspection (Approach A Canon)

    /// Idempotently inspects whether TradingView's Watchlist / Details right sidebar is open.
    /// Uses macOS Accessibility (AXUIElement) as primary source of factual truth.
    /// Returns:
    /// - true: Sidebar is confirmed OPEN (must be collapsed)
    /// - false: Sidebar is confirmed CLOSED/COLLAPSED (must NOT be touched)
    /// - nil: Indeterminate (AX element not readable)
    public func isWatchlistSidebarOpen() -> Bool? {
        guard let app = NSWorkspace.shared.runningApplications.first(where: {
            $0.bundleIdentifier == TradingViewInputSupport.bundleIdentifier || $0.localizedName == "TradingView"
        }) else {
            ClickyLogger.warning("[TRADINGVIEW_LAYOUT]", "Cannot inspect sidebar: TradingView process not found")
            return nil
        }

        guard let bounds = TradingViewInputSupport.getTradingViewWindowBounds() else {
            ClickyLogger.warning("[TRADINGVIEW_LAYOUT]", "Cannot inspect sidebar: TradingView window bounds unavailable")
            return nil
        }

        let pid = app.processIdentifier
        let appElement = AXUIElementCreateApplication(pid)

        // Wake Chromium / Electron Accessibility if idle
        AXUIElementSetAttributeValue(appElement, "AXEnhancedUserInterface" as CFString, kCFBooleanTrue)

        // Inspection Strategy 1 (Primary & Factual): Vision OCR on right 25% of window
        // In TradingView, if Watchlist is open, right 25% contains "Watchlist", "Symbols", "Last", "Chg", or multiple coin tickers.
        // If closed, right 25% only contains vertical price scale numbers (e.g. 2,820.00, UTC).
        if let info = TradingViewInputSupport.getTradingViewMainWindowInfo() {
            let rightTexts = TradingViewInputSupport.extractTextsFromWindowCrop(
                windowId: info.windowId,
                normalizedCropRect: CGRect(x: 0.75, y: 0.0, width: 0.25, height: 1.0)
            )
            let hasWatchlistIndicators = rightTexts.contains { t in
                let lower = t.lowercased()
                return lower.contains("watchlist") || lower.contains("symbol") || lower.contains("last") || lower.contains("chg")
            }
            if hasWatchlistIndicators {
                ClickyLogger.info("[TRADINGVIEW_LAYOUT]", "Vision OCR detected Watchlist panel indicators on right side -> OPEN")
                return true
            } else if !rightTexts.isEmpty {
                ClickyLogger.info("[TRADINGVIEW_LAYOUT]", "Vision OCR verified price scale only on right side -> CLOSED")
                return false
            }
        }

        // Inspection Strategy 2: Check the Watchlist Toggle button directly at the tool dock
        // In TradingView Desktop, the Watchlist toggle button sits at (X = bounds.maxX - 22, Y = bounds.origin.y + 88)
        let buttonX = Float(bounds.maxX - 22.0)
        let buttonY = Float(bounds.origin.y + 88.0)

        var elementAtPosRef: AXUIElement?
        if AXUIElementCopyElementAtPosition(appElement, buttonX, buttonY, &elementAtPosRef) == .success,
           let btn = elementAtPosRef {

            // Check AXSelected / AXValue / AXPressed
            var selRef: CFTypeRef?
            if AXUIElementCopyAttributeValue(btn, "AXSelected" as CFString, &selRef) == .success, let sel = selRef {
                if let num = sel as? NSNumber, num.intValue == 1 {
                    ClickyLogger.info("[TRADINGVIEW_LAYOUT]", "AX Watchlist button AXSelected: 1 -> isOpen: true")
                    return true
                } else if CFGetTypeID(sel) == CFBooleanGetTypeID(), CFBooleanGetValue((sel as! CFBoolean)) {
                    ClickyLogger.info("[TRADINGVIEW_LAYOUT]", "AX Watchlist button AXSelected CFBoolean: true")
                    return true
                }
            }

            var valRef: CFTypeRef?
            if AXUIElementCopyAttributeValue(btn, kAXValueAttribute as CFString, &valRef) == .success, let val = valRef {
                if let num = val as? NSNumber, num.intValue == 1 {
                    ClickyLogger.info("[TRADINGVIEW_LAYOUT]", "AX Watchlist button kAXValueAttribute: 1 -> isOpen: true")
                    return true
                } else if CFGetTypeID(val) == CFBooleanGetTypeID(), CFBooleanGetValue((val as! CFBoolean)) {
                    ClickyLogger.info("[TRADINGVIEW_LAYOUT]", "AX Watchlist button kAXValueAttribute CFBoolean: true")
                    return true
                }
            }
        }

        // Inspection Strategy 2: Window Children / Layout Area Inspection (Recursive depth <= 2)
        var windowListRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowListRef) == .success,
           let windows = windowListRef as? [AXUIElement],
           let mainWindow = windows.first {

            func scanElements(_ elements: [AXUIElement], depth: Int) -> Bool? {
                if depth > 2 { return nil }
                for child in elements {
                    var childPos = CGPoint.zero
                    var childSize = CGSize.zero

                    var posRef: CFTypeRef?
                    if AXUIElementCopyAttributeValue(child, kAXPositionAttribute as CFString, &posRef) == .success, let val = posRef {
                        AXValueGetValue(val as! AXValue, .cgPoint, &childPos)
                    }

                    var sizeRef: CFTypeRef?
                    if AXUIElementCopyAttributeValue(child, kAXSizeAttribute as CFString, &sizeRef) == .success, let val = sizeRef {
                        AXValueGetValue(val as! AXValue, .cgSize, &childSize)
                    }

                    // A visible Watchlist & Details panel has width ~180..480 pt and sits against the right toolbar dock
                    let isRightAligned = childPos.x >= bounds.maxX - 480 && (childPos.x + childSize.width) <= bounds.maxX
                    let hasSidebarWidth = childSize.width >= 180 && childSize.width <= 480
                    let hasSignificantHeight = childSize.height >= bounds.height * 0.5

                    if isRightAligned && hasSidebarWidth && hasSignificantHeight {
                        ClickyLogger.info("[TRADINGVIEW_LAYOUT]", "AX panel detected at pos=\(childPos) sz=\(childSize) -> Watchlist is OPEN")
                        return true
                    }

                    var subChildrenRef: CFTypeRef?
                    if AXUIElementCopyAttributeValue(child, kAXChildrenAttribute as CFString, &subChildrenRef) == .success,
                       let subChildren = subChildrenRef as? [AXUIElement] {
                        if let found = scanElements(subChildren, depth: depth + 1) {
                            return found
                        }
                    }
                }
                return nil
            }

            var childrenRef: CFTypeRef?
            if AXUIElementCopyAttributeValue(mainWindow, kAXChildrenAttribute as CFString, &childrenRef) == .success,
               let children = childrenRef as? [AXUIElement] {
                if let panelOpen = scanElements(children, depth: 1) {
                    return panelOpen
                }
            }
        }

        // Inspection Strategy 3: Fast Vision OCR fallback on right 25% of window
        // In TradingView, if Watchlist is open, right 25% contains "Watchlist", "Symbols", or ticker tables.
        // If closed, right 25% only contains vertical price scale numbers (e.g. 2,820.00, UTC).
        if let info = TradingViewInputSupport.getTradingViewMainWindowInfo() {
            let rightTexts = TradingViewInputSupport.extractTextsFromWindowCrop(
                windowId: info.windowId,
                normalizedCropRect: CGRect(x: 0.75, y: 0.0, width: 0.25, height: 1.0)
            )
            let hasWatchlistIndicators = rightTexts.contains { t in
                let lower = t.lowercased()
                return lower.contains("watchlist") || lower.contains("symbol") || lower.contains("chg")
            }
            if hasWatchlistIndicators {
                ClickyLogger.info("[TRADINGVIEW_LAYOUT]", "Vision OCR detected Watchlist panel indicators on right side -> OPEN")
                return true
            } else {
                ClickyLogger.info("[TRADINGVIEW_LAYOUT]", "Vision OCR verified price scale only on right side -> CLOSED")
                return false
            }
        }

        return nil
    }

    // MARK: - Idempotent Sidebar Collapse (Option + W / Right Toolbar Button)

    /// Idempotent Watchlist Collapse (Approach A Canon):
    /// - If Watchlist is confirmed OPEN -> collapses it via button click / Option+W.
    /// - If Watchlist is confirmed CLOSED/COLLAPSED -> NO-OP (0 clicks, zero flip-flop).
    /// - If indeterminate -> FAIL-CLOSED: NO-OP (0 clicks, never guess or disrupt user layout).
    @discardableResult
    public func collapseSidebarIfOpen() async -> Bool {
        ClickyLogger.info("[TRADINGVIEW_LAYOUT]", "Evaluating idempotent Watchlist collapse (Approach A)")
        guard await TradingViewInputSupport.activateTradingView() != nil else { return false }
        try? await Task.sleep(for: .milliseconds(120))

        let sidebarState = isWatchlistSidebarOpen()

        // STRICT FAIL-CLOSED IDEMPOTENT GUARD:
        // ONLY click if we have positive, factual confirmation that the sidebar is OPEN (sidebarState == true).
        // If sidebarState is false (already closed) OR nil (indeterminate/unverified),
        // WE MUST NOT CLICK! (0 clicks, zero flip-flop, 100% fail-closed).
        guard sidebarState == true else {
            if sidebarState == false {
                ClickyLogger.success("[TRADINGVIEW_LAYOUT]", "Idempotent Guard: Watchlist is confirmed CLOSED. 0 clicks performed (Anti-flip-flop enforced).")
            } else {
                ClickyLogger.warning("[TRADINGVIEW_LAYOUT]", "Idempotent Guard: Watchlist state is indeterminate via AX & OCR. FAIL-CLOSED: 0 clicks performed (preserving user layout).")
            }
            return true
        }

        ClickyLogger.info("[TRADINGVIEW_LAYOUT]", "Factual State: Watchlist is confirmed OPEN. Collapsing sidebar now...")
        let didPerform = await performSidebarToggleAction()
        if didPerform {
            ClickyLogger.success("[TRADINGVIEW_LAYOUT]", "Watchlist sidebar collapsed successfully")
        }
        return didPerform
    }

    /// Legacy alias for backward compatibility. Now strictly routes to idempotent collapseSidebarIfOpen().
    @discardableResult
    public func toggleSidebar() async -> Bool {
        return await collapseSidebarIfOpen()
    }

    private func performSidebarToggleAction() async -> Bool {
        if let bounds = TradingViewInputSupport.getTradingViewWindowBounds(),
           let pid = TradingViewInputSupport.tradingViewPID,
           let winInfo = TradingViewInputSupport.getTradingViewMainWindowInfo() {
            // Dynamic Snapshot Geometry: capture real snapshot dimensions from cua-driver
            var snapW: CGFloat = bounds.width * 1.36
            var snapH: CGFloat = bounds.height * 1.36
            let snapPath = "/tmp/tv_snap_watchlist.png"
            if let snap = try? await CuaDriverClient.shared.captureWindowSnapshot(pid: pid, windowId: Int64(winInfo.windowId), outPath: snapPath) {
                snapW = snap.width
                snapH = snap.height
            }

            // In TradingView Desktop, the top icon on the rightmost toolbar dock is the Watchlist toggle button.
            // Dock icon sits centered at ~20 pt from right edge, ~88 pt from top of window.
            let normX = (bounds.width - 20.0) / bounds.width
            let normY = 88.0 / bounds.height
            let pxX = normX * snapW
            let pxY = normY * snapH

            ClickyLogger.info("[TRADINGVIEW_LAYOUT]", "Moving native Cua-Driver cursor to Watchlist button at snapshot px (\(Int(pxX)), \(Int(pxY)))")
            _ = try? await CuaDriverClient.shared.moveCursor(pid: pid, windowId: Int64(winInfo.windowId), x: pxX, y: pxY)
            try? await Task.sleep(for: .milliseconds(120))
            _ = try? await CuaDriverClient.shared.clickPixel(pid: pid, windowId: Int64(winInfo.windowId), x: pxX, y: pxY)
            try? await Task.sleep(for: .milliseconds(250))

            // Check if still open; if so, trigger Option+W fallback
            if isWatchlistSidebarOpen() == true {
                ClickyLogger.warning("[TRADINGVIEW_LAYOUT]", "Watchlist button click didn't close panel. Triggering ⌥+W fallback...")
                await focusChartCanvas()
                TradingViewInputSupport.pressKey(CGKeyCode(kVK_ANSI_W), flags: [.maskAlternate])
                try? await Task.sleep(for: .milliseconds(200))
            }
        } else {
            // Fallback to keyboard shortcut Option + W
            await focusChartCanvas()
            try? await Task.sleep(for: .milliseconds(100))
            TradingViewInputSupport.pressKey(CGKeyCode(kVK_ANSI_W), flags: [.maskAlternate])
        }

        try? await Task.sleep(for: .milliseconds(200))

        // Reset chart scale after sidebar toggle to fill widened canvas
        let scaleOk = TradingViewInputSupport.pressKey(CGKeyCode(kVK_ANSI_R), flags: [.maskAlternate])
        try? await Task.sleep(for: .milliseconds(150))
        return scaleOk
    }

    // MARK: - All-in-one Workspace Setup

    @discardableResult
    public func setupWorkspace(symbol: String? = nil) async -> Bool {
        ClickyLogger.info("[TRADINGVIEW_LAYOUT]", "Executing all-in-one setupWorkspace: Maximize + Close Sidebar + Symbol Alignment")
        let maxOk = await maximizeWindow()
        try? await Task.sleep(for: .milliseconds(300))
        let sideOk = await collapseSidebarIfOpen()
        try? await Task.sleep(for: .milliseconds(300))
        var symOk = true
        if let sym = symbol, !sym.isEmpty {
            symOk = await TradingViewNavigationTool.shared.switchSymbol(sym)
            try? await Task.sleep(for: .milliseconds(300))
        }
        let scaleOk = await resetChartScale()
        return maxOk && sideOk && symOk && scaleOk
    }

    // MARK: - Canvas Focus

    public func focusChartCanvas() async {
        // Clear active text field / modal focus cleanly via Escape key (Zero blind canvas mouse clicking)
        TradingViewInputSupport.pressKey(CGKeyCode(kVK_Escape))
        try? await Task.sleep(for: .milliseconds(50))
    }

    // MARK: - Canvas Bounds Calculation (Excluding Sidebar)

    /// Returns the true bounding box of the candlestick chart canvas,
    /// safely excluding left drawing toolbar and any right-side Watchlist/Details panel.
    public func getChartCanvasRect(hasSidebar: Bool = false) -> CGRect {
        guard let b = TradingViewInputSupport.getTradingViewWindowBounds() else {
            return CGRect(x: 100, y: 100, width: 800, height: 600)
        }

        let leftToolbarMargin: CGFloat = 52.0
        let topHeaderMargin: CGFloat = 38.0
        let bottomStatusMargin: CGFloat = 32.0
        let rightSidebarMargin: CGFloat = hasSidebar ? 280.0 : 50.0 // 50pt price scale when closed

        return CGRect(
            x: b.origin.x + leftToolbarMargin,
            y: b.origin.y + topHeaderMargin,
            width: max(200, b.width - leftToolbarMargin - rightSidebarMargin),
            height: max(200, b.height - topHeaderMargin - bottomStatusMargin)
        )
    }

    // MARK: - Auto-Scale & Price Scale Reset (Option + R)

    @discardableResult
    public func resetChartScale() async -> Bool {
        ClickyLogger.info("[TRADINGVIEW_LAYOUT]", "Resetting chart price scale to Auto-Fit via ⌥+R")
        // Defensive Invariant: Guarantee focus is on the candlestick chart canvas before sending Option+R
        // This prevents Option+R from being interpreted as the '®' registered trademark character in text editors
        await focusChartCanvas()
        let ok = TradingViewInputSupport.pressKey(CGKeyCode(kVK_ANSI_R), flags: [.maskAlternate])
        try? await Task.sleep(for: .milliseconds(200))
        return ok
    }

    // MARK: - Modal & Popup Dismissal

    @discardableResult
    public func dismissActiveModals() async -> Bool {
        ClickyLogger.info("[TRADINGVIEW_LAYOUT]", "Dismissing active modals via double Escape")
        let ok1 = TradingViewInputSupport.pressKey(CGKeyCode(kVK_Escape))
        try? await Task.sleep(for: .milliseconds(80))
        let ok2 = TradingViewInputSupport.pressKey(CGKeyCode(kVK_Escape))
        try? await Task.sleep(for: .milliseconds(100))
        return ok1 && ok2
    }
}
