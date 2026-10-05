//
//  TradingViewInputSupport.swift
//  boringNotch
//
//  Low-Level Hardware Keystroke, Mouse Movement & Window Management Engine
//  Reusable across multiple companions and application controllers
//

import AppKit
import ApplicationServices
import Carbon.HIToolbox
import Foundation
import Vision

@MainActor
public enum TradingViewInputSupport {
    public static let bundleIdentifier = "com.tradingview.tradingviewapp.desktop"
    public static let appPath = "/Applications/TradingView.app"

    /// Discovers the active process identifier for TradingView.app
    public static var tradingViewPID: Int32? {
        let runningApps = NSWorkspace.shared.runningApplications
        let app = runningApps.first { $0.bundleIdentifier == bundleIdentifier } ??
                  runningApps.first { $0.localizedName == "TradingView" }
        return app?.processIdentifier
    }

    // MARK: - App Activation

    @discardableResult
    public static func activateTradingView() async -> NSRunningApplication? {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        proc.arguments = ["-a", appPath]
        try? proc.run()

        let runningApps = NSWorkspace.shared.runningApplications
        let script = """
        tell application "TradingView"
            activate
            reopen
        end tell
        tell application "System Events"
            tell process "TradingView"
                set frontmost to true
            end tell
        end tell
        """

        if let app = runningApps.first(where: { $0.bundleIdentifier == bundleIdentifier }) ??
                     runningApps.first(where: { $0.localizedName == "TradingView" }) {
            app.activate()
            if let appleScript = NSAppleScript(source: script) {
                var err: NSDictionary?
                appleScript.executeAndReturnError(&err)
            }
            let isReady = await waitForTradingViewReady(timeout: 2.5)
            if isReady {
                ClickyLogger.info("[TRADINGVIEW_INPUT]", "Warm activation verified: TradingView is frontmost and ready in WindowServer (Layer 0)")
            } else {
                ClickyLogger.warning("[TRADINGVIEW_INPUT]", "Warm activation TIMEOUT: TradingView window not confirmed frontmost/ready within 2.5s")
            }
            return app
        }

        let appURL = URL(fileURLWithPath: appPath)
        let config = NSWorkspace.OpenConfiguration()
        config.activates = true

        do {
            let app = try await NSWorkspace.shared.openApplication(at: appURL, configuration: config)
            app.activate()
            if let appleScript = NSAppleScript(source: script) {
                var err: NSDictionary?
                appleScript.executeAndReturnError(&err)
            }
            let isReady = await waitForTradingViewReady(timeout: 2.5)
            if isReady {
                ClickyLogger.info("[TRADINGVIEW_INPUT]", "Cold-start activation verified: TradingView is frontmost and ready in WindowServer (Layer 0)")
            } else {
                ClickyLogger.warning("[TRADINGVIEW_INPUT]", "Cold-start activation TIMEOUT: TradingView window not confirmed frontmost/ready within 2.5s")
            }
            return app
        } catch {
            ClickyLogger.error("[TRADINGVIEW_INPUT]", "Error opening TradingView: \(error)")
            return nil
        }
    }

    // MARK: - Frontmost & Permission Guards

    public static func isTradingViewFrontmost() -> Bool {
        guard let front = NSWorkspace.shared.frontmostApplication else { return false }
        return front.bundleIdentifier == bundleIdentifier || front.localizedName == "TradingView"
    }

    // MARK: - Local Fast Vision Probes (Deterministic UI State Gates)

    /// Captures a target window crop and extracts visible text lines using Apple Vision Fast OCR (10-20ms, 100% offline).
    public nonisolated static func extractTextsFromWindowCrop(windowId: CGWindowID, normalizedCropRect: CGRect) -> [String] {
        let tempPath = "/tmp/tv_vision_probe_\(windowId).png"
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        proc.arguments = ["-x", "-l", "\(windowId)", tempPath]
        try? proc.run()
        proc.waitUntilExit()

        guard let imgSource = CGImageSourceCreateWithURL(URL(fileURLWithPath: tempPath) as CFURL, nil),
              let cgImage = CGImageSourceCreateImageAtIndex(imgSource, 0, nil) else {
            return []
        }

        let cropX = Int(Double(cgImage.width) * Double(normalizedCropRect.origin.x))
        let cropY = Int(Double(cgImage.height) * Double(normalizedCropRect.origin.y))
        let cropW = Int(Double(cgImage.width) * Double(normalizedCropRect.width))
        let cropH = Int(Double(cgImage.height) * Double(normalizedCropRect.height))
        let cropRect = CGRect(x: cropX, y: cropY, width: max(cropW, 10), height: max(cropH, 10))

        guard let cropped = cgImage.cropping(to: cropRect) else { return [] }

        let req = VNRecognizeTextRequest()
        req.recognitionLevel = .fast
        let handler = VNImageRequestHandler(cgImage: cropped, options: [:])
        try? handler.perform([req])

        return req.results?.compactMap { $0.topCandidates(1).first?.string } ?? []
    }

    /// Gate 1B: Verifies that TradingView's toolbar anchors are physically rendered on screen (not splash/loading screen).
    public nonisolated static func isTradingViewUIRendered(windowId: CGWindowID) -> Bool {
        // Toolbar is located in top 15% of window
        let texts = extractTextsFromWindowCrop(windowId: windowId, normalizedCropRect: CGRect(x: 0, y: 0, width: 1.0, height: 0.15))
        for t in texts {
            if t.contains("Trade") || t.contains("Publish") || t.contains("Unnamed") || t.contains("USDT") || t.contains("BTC") || t.contains("ETH") || t.contains("SOL") {
                return true
            }
        }
        return false
    }

    /// Gate 2B: Verifies that live candlestick OHLC and price scale have finished downloading and rendering on the chart canvas.
    public nonisolated static func isChartDataSettled(windowId: CGWindowID) -> Bool {
        // Status header & top chart is in top 28% of window
        let texts = extractTextsFromWindowCrop(windowId: windowId, normalizedCropRect: CGRect(x: 0, y: 0, width: 1.0, height: 0.28))
        return texts.contains { t in
            let hasOHLC = t.range(of: "[HhLlCcOo0]\\s*[0-9]{1,6}[.,][0-9]{1,4}", options: .regularExpression) != nil
            let hasPercent = t.range(of: "[+-]?[0-9]+[.,][0-9]+%", options: .regularExpression) != nil
            let hasBuySell = t.contains("BUY") || t.contains("SELL")
            return hasOHLC || hasPercent || hasBuySell
        }
    }

    /// Gate 3B: Verifies that the requested timeframe interval (e.g. "15" or "1h") is settled on the chart header or toolbar.
    public nonisolated static func isTimeframeSettled(windowId: CGWindowID, targetTimeframe: String) -> Bool {
        let texts = extractTextsFromWindowCrop(windowId: windowId, normalizedCropRect: CGRect(x: 0, y: 0, width: 1.0, height: 0.25))
        let cleanTf = targetTimeframe.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let tfVariants: [String] = {
            if cleanTf == "15" || cleanTf == "15m" { return ["15m", "15 m", "15"] }
            if cleanTf == "60" || cleanTf == "1h" || cleanTf == "1" { return ["1h", "1 h", "60m"] }
            if cleanTf == "5" || cleanTf == "5m" { return ["5m", "5 m", "5"] }
            if cleanTf == "d" || cleanTf == "1d" { return ["1d", "1 d", "D"] }
            return [cleanTf]
        }()
        for t in texts {
            for v in tfVariants {
                if t.contains(v) { return true }
            }
        }
        return false
    }

    // MARK: - Window Readiness Polling (Phase 1 Hybrid Double Gate)

    /// Waits asynchronously for TradingView window to transition from splash/loading screen to a fully rendered interactive state.
    /// True 2-Layer Short-Circuit Architecture:
    /// - Layer 1 (Fast Native WindowServer, ~0.1ms): In-memory title transition check. If passed, immediately returns true (zero screenshots, zero OCR, zero sound).
    /// - Layer 2 (Vision Fast OCR Fallback, muted with -x): Runs only if Layer 1 has not transitioned after a 1.5s grace period.
    @discardableResult
    public static func waitForTradingViewReady(timeout: TimeInterval = 6.0) async -> Bool {
        let startTime = Date()
        let isReady = await pollUntil(timeout: timeout, interval: 0.1) {
            guard await MainActor.run(body: { isTradingViewFrontmost() }) else { return false }
            guard let info = getTradingViewMainWindowInfo(),
                  info.bounds.width >= 600 && info.bounds.height >= 400 else {
                return false
            }

            // Layer 1: WindowServer Title Transition Gate (0.1ms in-memory, 0 screenshot, 0 sound)
            let title = info.title.trimmingCharacters(in: .whitespacesAndNewlines)
            let isTitleTransitioned = !title.isEmpty && title != "TradingView" && (title.contains("/") || title.contains(".P") || title.contains("USDT") || title.contains("USD") || title.contains("—") || title.contains("-"))

            if isTitleTransitioned {
                return true // Short-circuit Layer 1! Zero screenshot, zero sound.
            }

            // Layer 2 Fallback: Vision Fast OCR Toolbar Anchors (runs only if title hasn't transitioned after 1.5s)
            if Date().timeIntervalSince(startTime) > 1.5 {
                return isTradingViewUIRendered(windowId: info.windowId)
            }

            return false
        }
        if isReady, let info = getTradingViewMainWindowInfo() {
            ClickyLogger.success("[TRADINGVIEW_INPUT]", "Fase 1 Gate Verified: windowId=\(info.windowId), bounds=\(info.bounds), title='\(info.title)'")
        } else {
            ClickyLogger.warning("[TRADINGVIEW_INPUT]", "Fase 1 Gate TIMEOUT (\(timeout)s): TradingView did not reach interactive UI state")
        }
        return isReady
    }

    /// Scoped security gate: Cmd+C clipboard read is strictly locked down and ONLY permitted
    /// during the non-destructive Pine Editor backup sequence in injectPineScript (Agent 2 specification).
    public static var isPineScriptBackupActive: Bool = false

    // Centralized Allowlist Enforcer (Node 03 & Whitelist Invariant)
    // Only approved navigation, editing, and palette keys are permitted.
    // Order execution hotkeys (Shift+B, Shift+S, Alt+B, Alt+S, etc.) are strictly prohibited.
    public static func isAllowedKey(_ keyCode: CGKeyCode, flags: CGEventFlags) -> Bool {
        // Explicitly reject order hotkeys: 'B' or 'S' with Shift/Alt/Option modifier
        let isB = keyCode == CGKeyCode(kVK_ANSI_B)
        let isS = keyCode == CGKeyCode(kVK_ANSI_S)
        if (isB || isS) && (flags.contains(.maskShift) || flags.contains(.maskAlternate) || flags.contains(.maskControl)) {
            ClickyLogger.error("[TRADINGVIEW_SECURITY]", "VETO: Blocked dangerous order hotkey: \(keyCode) with flags \(flags.rawValue)")
            return false
        }

        // Explicitly reject window-close shortcut: 'Cmd+W'
        if keyCode == CGKeyCode(kVK_ANSI_W) && flags.contains(.maskCommand) {
            ClickyLogger.error("[TRADINGVIEW_SECURITY]", "VETO: Blocked dangerous window-close shortcut Cmd+W")
            return false
        }

        // Permitted keys:
        switch keyCode {
        case CGKeyCode(kVK_Escape):
            return true
        case CGKeyCode(kVK_Return):
            return flags.isEmpty || flags == [.maskCommand]
        case CGKeyCode(kVK_ANSI_R):
            return flags.isEmpty || flags == [.maskAlternate] // Option + R (Auto-fit chart scale)
        case CGKeyCode(kVK_ANSI_W):
            return flags.isEmpty || flags == [.maskAlternate] // Option + W only (Toggle sidebar). Cmd+W strictly rejected
        case CGKeyCode(kVK_ANSI_E):
            return flags.isEmpty // Plain 'E' key only. Option+E completely deprecated (dead key ´ on macOS)
        case CGKeyCode(kVK_ANSI_T):
            return flags.isEmpty || flags == [.maskAlternate] // Option + T (Trend Line)
        case CGKeyCode(kVK_ANSI_F):
            return flags.isEmpty || flags == [.maskAlternate] // Option + F (Fibonacci Retracement)
        case CGKeyCode(kVK_ANSI_H), CGKeyCode(kVK_ANSI_J):
            return flags == [.maskAlternate] // Option + H / J (Horizontal Line / Ray)
        case CGKeyCode(kVK_ANSI_K):
            return flags == [.maskCommand] || flags == [.maskCommand, .maskAlternate] // Cmd + K (Palette), Cmd + Option + K (Clear all drawings)
        case CGKeyCode(kVK_ANSI_A), CGKeyCode(kVK_ANSI_V), CGKeyCode(kVK_ANSI_Z):
            return flags == [.maskCommand] // Cmd + A, Cmd + V, Cmd + Z
        case CGKeyCode(kVK_ANSI_C):
            // Cmd + C is strictly scoped to injectPineScript backup window only (Agent 2 requirement)
            return flags == [.maskCommand] && isPineScriptBackupActive
        case CGKeyCode(kVK_Option), CGKeyCode(kVK_RightOption):
            return flags.isEmpty || flags == [.maskAlternate] // Standalone Option key (macOS green button zoom)
        case CGKeyCode(kVK_Delete):
            return flags.isEmpty || flags == [.maskCommand]
        case CGKeyCode(kVK_DownArrow), CGKeyCode(kVK_UpArrow), CGKeyCode(kVK_LeftArrow), CGKeyCode(kVK_RightArrow):
            return flags.isEmpty // Arrow keys for palette navigation
        case CGKeyCode(kVK_ANSI_Slash):
            return flags.isEmpty // '/' for indicator search
        case CGKeyCode(kVK_ANSI_0), CGKeyCode(kVK_ANSI_1), CGKeyCode(kVK_ANSI_2), CGKeyCode(kVK_ANSI_3),
             CGKeyCode(kVK_ANSI_4), CGKeyCode(kVK_ANSI_5), CGKeyCode(kVK_ANSI_6), CGKeyCode(kVK_ANSI_7),
             CGKeyCode(kVK_ANSI_8), CGKeyCode(kVK_ANSI_9):
            return flags.isEmpty // Explicit digit keycodes for timeframes (Anti-reverse range)
        case CGKeyCode(kVK_Space), CGKeyCode(kVK_Tab):
            return flags.isEmpty
        default:
            // Strictly Fail-Closed: Unknown keys with or without modifiers are prohibited (Agent 1 requirement)
            return false
        }
    }

    // MARK: - Window Bounds & Main Window Query

    public nonisolated static func getTradingViewMainWindowInfo() -> (windowId: CGWindowID, bounds: CGRect, title: String)? {
        let options = CGWindowListOption(arrayLiteral: .excludeDesktopElements)
        guard let infoList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return nil
        }

        var candidates: [(windowId: CGWindowID, bounds: CGRect, title: String, area: CGFloat, isPreferredTitle: Bool)] = []
        for info in infoList {
            let ownerName = info[kCGWindowOwnerName as String] as? String ?? ""
            let layer = info[kCGWindowLayer as String] as? Int ?? 0
            if layer == 0 && (ownerName == "TradingView" || ownerName.contains("TradingView")) {
                if let boundsDict = info[kCGWindowBounds as String] as? [String: Any],
                   let x = boundsDict["X"] as? CGFloat,
                   let y = boundsDict["Y"] as? CGFloat,
                   let width = boundsDict["Width"] as? CGFloat,
                   let height = boundsDict["Height"] as? CGFloat,
                   let windowId = info[kCGWindowNumber as String] as? CGWindowID,
                   width >= 600 && height >= 400 {
                    let title = info[kCGWindowName as String] as? String ?? ""
                    let isPreferred = title.contains("BTC") || title.contains("USDT") || title.contains("Chart") || title.contains("/") || title.contains("Unnamed")
                    candidates.append((windowId, CGRect(x: x, y: y, width: width, height: height), title, width * height, isPreferred))
                }
            }
        }

        // Prioritize windows with chart/symbol title, then by largest canvas area
        if let preferred = candidates.filter({ $0.isPreferredTitle }).max(by: { $0.area < $1.area }) {
            return (preferred.windowId, preferred.bounds, preferred.title)
        }
        if let largest = candidates.max(by: { $0.area < $1.area }) {
            return (largest.windowId, largest.bounds, largest.title)
        }
        return nil
    }

    public nonisolated static func getTradingViewWindowBounds() -> CGRect? {
        return getTradingViewMainWindowInfo()?.bounds
    }

    // MARK: - Safe Coordinate Resolution (Fail-Closed Canvas Boundary)

    /// Resolves normalized (0.0...1.0) or physical coordinates inside TradingView window canvas.
    /// Strictly fail-closed: returns nil if windowBounds is nil or point is outside window bounds.
    public static func resolvePoint(_ pt: CGPoint, windowBounds: CGRect?) -> CGPoint? {
        guard let bounds = windowBounds else {
            ClickyLogger.error("[TRADINGVIEW_SECURITY]", "VETO: resolvePoint failed - TradingView window bounds unavailable (Fail-Closed)")
            return nil
        }

        let rawPt: CGPoint
        if pt.x <= 1.0 && pt.y <= 1.0 {
            rawPt = CGPoint(
                x: bounds.origin.x + pt.x * bounds.width,
                y: bounds.origin.y + pt.y * bounds.height
            )
        } else {
            rawPt = pt
        }

        // Safety margin: coordinates must be within or immediately adjacent to TradingView window
        guard rawPt.x >= bounds.minX - 50 && rawPt.x <= bounds.maxX + 50 &&
              rawPt.y >= bounds.minY - 50 && rawPt.y <= bounds.maxY + 50 else {
            ClickyLogger.error("[TRADINGVIEW_SECURITY]", "VETO: point \(rawPt) is outside TradingView window bounds \(bounds) (Fail-Closed)")
            return nil
        }

        // Containment Guard: Strictly clamp physical coordinates inside TradingView window canvas
        let minX = bounds.minX + 20.0
        let maxX = bounds.maxX - 20.0
        let minY = bounds.minY + 45.0
        let maxY = bounds.maxY - 35.0

        let clampedX = min(max(rawPt.x, minX), maxX)
        let clampedY = min(max(rawPt.y, minY), maxY)
        return CGPoint(x: clampedX, y: clampedY)
    }

    // MARK: - Adaptive Asynchronous Polling Engine (Node 01 Invariant & Anti-Lag)

    /// Polls an asynchronous condition at regular intervals until it evaluates to true or times out.
    /// Eliminates static blind sleeps and adapts dynamically to UI and WebGL rendering speed.
    @discardableResult
    public static func pollUntil(
        timeout: TimeInterval = 1.5,
        interval: TimeInterval = 0.05,
        condition: @Sendable () async -> Bool
    ) async -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if await condition() { return true }
            try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
        }
        return await condition()
    }

    // MARK: - Keystroke Simulation

    @discardableResult
    public static func pressKey(_ keyCode: CGKeyCode, flags: CGEventFlags = []) -> Bool {
        // 1. Enforce Centralized Keystroke Allowlist
        guard isAllowedKey(keyCode, flags: flags) else {
            ClickyLogger.error("[TRADINGVIEW_INPUT]", "Blocked unauthorized keycode \(keyCode) with flags \(flags.rawValue)")
            return false
        }

        // 2. Enforce Frontmost Application Gate
        guard isTradingViewFrontmost() else {
            ClickyLogger.warning("[TRADINGVIEW_INPUT]", "Blocked keystroke: TradingView is not frontmost")
            return false
        }

        if keyCode == CGKeyCode(kVK_Escape) {
            GlobalPushToTalkShortcutMonitor.isSynthesizingInput = true
        }
        let source = CGEventSource(stateID: .hidSystemState)
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true)
        keyDown?.flags = flags
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)
        keyUp?.flags = flags

        keyDown?.post(tap: .cghidEventTap)
        usleep(30000)
        keyUp?.post(tap: .cghidEventTap)
        usleep(25000)

        if keyCode == CGKeyCode(kVK_Escape) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                GlobalPushToTalkShortcutMonitor.isSynthesizingInput = false
            }
        }
        return true
    }

    @discardableResult
    public static func typeStringSlowly(_ text: String) -> Bool {
        guard isTradingViewFrontmost() else {
            ClickyLogger.warning("[TRADINGVIEW_INPUT]", "Blocked typing: TradingView is not frontmost")
            return false
        }
        let source = CGEventSource(stateID: .hidSystemState)
        for char in text {
            let utf16Chars = Array(String(char).utf16)
            let mapping = hardwareKeyCode(for: char)
            let keyCode = mapping?.keyCode ?? 0
            var flags: CGEventFlags = []
            if mapping?.shift == true {
                flags.insert(.maskShift)
            }

            let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true)
            keyDown?.flags = flags
            keyDown?.keyboardSetUnicodeString(stringLength: utf16Chars.count, unicodeString: utf16Chars)
            keyDown?.post(tap: .cghidEventTap)
            usleep(25000)

            let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)
            keyUp?.flags = flags
            keyUp?.keyboardSetUnicodeString(stringLength: utf16Chars.count, unicodeString: utf16Chars)
            keyUp?.post(tap: .cghidEventTap)
            usleep(25000)
        }
        return true
    }

    // MARK: - Mouse Simulation

    public static func moveMouseSmoothly(to destination: CGPoint) {
        guard isTradingViewFrontmost() else {
            ClickyLogger.warning("[TRADINGVIEW_SECURITY]", "VETO: moveMouseSmoothly suppressed because TradingView is not frontmost")
            return
        }
        let currentPos = NSEvent.mouseLocation
        let startPoint = CGPoint(x: currentPos.x, y: (NSScreen.main?.frame.height ?? 900) - currentPos.y)
        let steps = 12

        for i in 1...steps {
            let t = CGFloat(i) / CGFloat(steps)
            let currentX = startPoint.x + (destination.x - startPoint.x) * t
            let currentY = startPoint.y + (destination.y - startPoint.y) * t
            let moveEvent = CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: CGPoint(x: currentX, y: currentY), mouseButton: .left)
            moveEvent?.post(tap: .cghidEventTap)
            usleep(8000)
        }
    }

    @discardableResult
    public static func clickMouse(at point: CGPoint) -> Bool {
        guard isTradingViewFrontmost() else {
            ClickyLogger.warning("[TRADINGVIEW_SECURITY]", "VETO: clickMouse suppressed because TradingView is not frontmost")
            return false
        }
        let down = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown, mouseCursorPosition: point, mouseButton: .left)
        let up = CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp, mouseCursorPosition: point, mouseButton: .left)
        down?.post(tap: .cghidEventTap)
        usleep(35000)
        up?.post(tap: .cghidEventTap)
        usleep(20000)
        return true
    }

    /// Performs low-level hardware click directly at destination and immediately restores the user's physical mouse cursor position.
    /// Eliminates physical cursor hijacking while delivering the click event directly to the target UI element.
    @discardableResult
    public static func clickMouseDirectly(at point: CGPoint, restoreUserCursor: Bool = true) -> Bool {
        guard isTradingViewFrontmost() else {
            ClickyLogger.warning("[TRADINGVIEW_SECURITY]", "VETO: clickMouseDirectly suppressed because TradingView is not frontmost")
            return false
        }
        let userPos = NSEvent.mouseLocation
        let primaryHeight = NSScreen.screens.first?.frame.height ?? 900.0
        let userCGPos = CGPoint(x: userPos.x, y: primaryHeight - userPos.y)

        let down = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown, mouseCursorPosition: point, mouseButton: .left)
        let up = CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp, mouseCursorPosition: point, mouseButton: .left)
        down?.post(tap: .cghidEventTap)
        usleep(35000)
        up?.post(tap: .cghidEventTap)
        usleep(20000)

        if restoreUserCursor {
            let restoreMove = CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: userCGPos, mouseButton: .left)
            restoreMove?.post(tap: .cghidEventTap)
        }
        return true
    }

    @discardableResult
    public static func dragMouse(from start: CGPoint, to end: CGPoint, steps: Int = 18) -> Bool {
        guard isTradingViewFrontmost() else {
            ClickyLogger.warning("[TRADINGVIEW_SECURITY]", "VETO: dragMouse suppressed because TradingView is not frontmost")
            return false
        }
        let source = CGEventSource(stateID: .hidSystemState)

        // 1. Move to start handle position and allow TradingView WebGL canvas to detect hover
        let move = CGEvent(mouseEventSource: source, mouseType: .mouseMoved, mouseCursorPosition: start, mouseButton: .left)
        move?.post(tap: .cghidEventTap)
        usleep(120000)

        // 2. Mouse down to firmly grab handle
        let down = CGEvent(mouseEventSource: source, mouseType: .leftMouseDown, mouseCursorPosition: start, mouseButton: .left)
        down?.post(tap: .cghidEventTap)
        usleep(80000)

        // 3. Smooth drag interpolation
        for i in 1...steps {
            let t = CGFloat(i) / CGFloat(steps)
            let curr = CGPoint(
                x: start.x + (end.x - start.x) * t,
                y: start.y + (end.y - start.y) * t
            )
            let drag = CGEvent(mouseEventSource: source, mouseType: .leftMouseDragged, mouseCursorPosition: curr, mouseButton: .left)
            drag?.post(tap: .cghidEventTap)
            usleep(16000)
        }

        // 4. Mouse up to drop handle
        let up = CGEvent(mouseEventSource: source, mouseType: .leftMouseUp, mouseCursorPosition: end, mouseButton: .left)
        up?.post(tap: .cghidEventTap)
        usleep(80000)
        return true
    }

    // MARK: - Keycode Mapping

    private static func hardwareKeyCode(for char: Character) -> (keyCode: CGKeyCode, shift: Bool)? {
        switch char {
        case "a": return (CGKeyCode(kVK_ANSI_A), false)
        case "A": return (CGKeyCode(kVK_ANSI_A), true)
        case "b": return (CGKeyCode(kVK_ANSI_B), false)
        case "B": return (CGKeyCode(kVK_ANSI_B), true)
        case "c": return (CGKeyCode(kVK_ANSI_C), false)
        case "C": return (CGKeyCode(kVK_ANSI_C), true)
        case "d": return (CGKeyCode(kVK_ANSI_D), false)
        case "D": return (CGKeyCode(kVK_ANSI_D), true)
        case "e": return (CGKeyCode(kVK_ANSI_E), false)
        case "E": return (CGKeyCode(kVK_ANSI_E), true)
        case "f": return (CGKeyCode(kVK_ANSI_F), false)
        case "F": return (CGKeyCode(kVK_ANSI_F), true)
        case "g": return (CGKeyCode(kVK_ANSI_G), false)
        case "G": return (CGKeyCode(kVK_ANSI_G), true)
        case "h": return (CGKeyCode(kVK_ANSI_H), false)
        case "H": return (CGKeyCode(kVK_ANSI_H), true)
        case "i": return (CGKeyCode(kVK_ANSI_I), false)
        case "I": return (CGKeyCode(kVK_ANSI_I), true)
        case "j": return (CGKeyCode(kVK_ANSI_J), false)
        case "J": return (CGKeyCode(kVK_ANSI_J), true)
        case "k": return (CGKeyCode(kVK_ANSI_K), false)
        case "K": return (CGKeyCode(kVK_ANSI_K), true)
        case "l": return (CGKeyCode(kVK_ANSI_L), false)
        case "L": return (CGKeyCode(kVK_ANSI_L), true)
        case "m": return (CGKeyCode(kVK_ANSI_M), false)
        case "M": return (CGKeyCode(kVK_ANSI_M), true)
        case "n": return (CGKeyCode(kVK_ANSI_N), false)
        case "N": return (CGKeyCode(kVK_ANSI_N), true)
        case "o": return (CGKeyCode(kVK_ANSI_O), false)
        case "O": return (CGKeyCode(kVK_ANSI_O), true)
        case "p": return (CGKeyCode(kVK_ANSI_P), false)
        case "P": return (CGKeyCode(kVK_ANSI_P), true)
        case "q": return (CGKeyCode(kVK_ANSI_Q), false)
        case "Q": return (CGKeyCode(kVK_ANSI_Q), true)
        case "r": return (CGKeyCode(kVK_ANSI_R), false)
        case "R": return (CGKeyCode(kVK_ANSI_R), true)
        case "s": return (CGKeyCode(kVK_ANSI_S), false)
        case "S": return (CGKeyCode(kVK_ANSI_S), true)
        case "t": return (CGKeyCode(kVK_ANSI_T), false)
        case "T": return (CGKeyCode(kVK_ANSI_T), true)
        case "u": return (CGKeyCode(kVK_ANSI_U), false)
        case "U": return (CGKeyCode(kVK_ANSI_U), true)
        case "v": return (CGKeyCode(kVK_ANSI_V), false)
        case "V": return (CGKeyCode(kVK_ANSI_V), true)
        case "w": return (CGKeyCode(kVK_ANSI_W), false)
        case "W": return (CGKeyCode(kVK_ANSI_W), true)
        case "x": return (CGKeyCode(kVK_ANSI_X), false)
        case "X": return (CGKeyCode(kVK_ANSI_X), true)
        case "y": return (CGKeyCode(kVK_ANSI_Y), false)
        case "Y": return (CGKeyCode(kVK_ANSI_Y), true)
        case "z": return (CGKeyCode(kVK_ANSI_Z), false)
        case "Z": return (CGKeyCode(kVK_ANSI_Z), true)

        case "0": return (CGKeyCode(kVK_ANSI_0), false)
        case "1": return (CGKeyCode(kVK_ANSI_1), false)
        case "2": return (CGKeyCode(kVK_ANSI_2), false)
        case "3": return (CGKeyCode(kVK_ANSI_3), false)
        case "4": return (CGKeyCode(kVK_ANSI_4), false)
        case "5": return (CGKeyCode(kVK_ANSI_5), false)
        case "6": return (CGKeyCode(kVK_ANSI_6), false)
        case "7": return (CGKeyCode(kVK_ANSI_7), false)
        case "8": return (CGKeyCode(kVK_ANSI_8), false)
        case "9": return (CGKeyCode(kVK_ANSI_9), false)

        case ")": return (CGKeyCode(kVK_ANSI_0), true)
        case "!": return (CGKeyCode(kVK_ANSI_1), true)
        case "@": return (CGKeyCode(kVK_ANSI_2), true)
        case "#": return (CGKeyCode(kVK_ANSI_3), true)
        case "$": return (CGKeyCode(kVK_ANSI_4), true)
        case "%": return (CGKeyCode(kVK_ANSI_5), true)
        case "^": return (CGKeyCode(kVK_ANSI_6), true)
        case "&": return (CGKeyCode(kVK_ANSI_7), true)
        case "*": return (CGKeyCode(kVK_ANSI_8), true)
        case "(": return (CGKeyCode(kVK_ANSI_9), true)

        case " ": return (CGKeyCode(kVK_Space), false)
        case "\n", "\r": return (CGKeyCode(kVK_Return), false)
        case "\t": return (CGKeyCode(kVK_Tab), false)
        case "-": return (CGKeyCode(kVK_ANSI_Minus), false)
        case "_": return (CGKeyCode(kVK_ANSI_Minus), true)
        case "=": return (CGKeyCode(kVK_ANSI_Equal), false)
        case "+": return (CGKeyCode(kVK_ANSI_Equal), true)
        case "/": return (CGKeyCode(kVK_ANSI_Slash), false)
        case "?": return (CGKeyCode(kVK_ANSI_Slash), true)
        case ";": return (CGKeyCode(kVK_ANSI_Semicolon), false)
        case ":": return (CGKeyCode(kVK_ANSI_Semicolon), true)
        case ",": return (CGKeyCode(kVK_ANSI_Comma), false)
        case "<": return (CGKeyCode(kVK_ANSI_Comma), true)
        case ".": return (CGKeyCode(kVK_ANSI_Period), false)
        case ">": return (CGKeyCode(kVK_ANSI_Period), true)
        default: return nil
        }
    }
}
