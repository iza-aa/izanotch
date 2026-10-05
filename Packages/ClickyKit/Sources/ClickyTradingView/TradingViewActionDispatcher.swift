import ClickyPlatform
import ClickyReasoning
import ClickyCUA
import ClickyFoundation
//
//  TradingViewActionDispatcher.swift
//  boringNotch
//
//  Modular TradingView Action Router & Facade
//  Coordinates specialized tool modules (LayoutTool, NavigationTool, DrawingTool)
//  Reusable across all companions in the Izanotchy multi-agent system.
//

import AppKit
import Carbon.HIToolbox
import Foundation

// MARK: - Single-Flight Run-Lock Actor (Node 01 Invariant)

public actor FuturesScoutRunLock {
    public static let shared = FuturesScoutRunLock()

    private var isLocked: Bool = false
    private var lockTimestamp: Date?
    private var activeTraceId: String = ""
    private var lockDepth: Int = 0
    private let timeoutInterval: TimeInterval = 25.0 // 25 seconds auto-release timeout

    private init() {}

    public func tryAcquire(traceId: String = "") -> Bool {
        let now = Date()
        if isLocked {
            // Re-entrant lock acquisition for same traceId (e.g. child steps in a .chain)
            if !activeTraceId.isEmpty && activeTraceId == traceId {
                lockDepth += 1
                ClickyLogger.info("[RUN_LOCK]", "Re-entrant lock acquired (depth: \(lockDepth)) for trace: \(traceId)")
                return true
            }
            if let ts = lockTimestamp, now.timeIntervalSince(ts) > timeoutInterval {
                ClickyLogger.warning("[RUN_LOCK]", "Auto-released stale lock after 25s for trace: \(traceId)")
                isLocked = true
                activeTraceId = traceId
                lockDepth = 1
                lockTimestamp = now
                return true
            }
            ClickyLogger.warning("[RUN_LOCK]", "Request rejected: CUA run-lock currently active for trace: \(traceId)")
            return false
        }
        isLocked = true
        activeTraceId = traceId
        lockDepth = 1
        lockTimestamp = now
        ClickyLogger.info("[RUN_LOCK]", "Acquired single-flight lock for trace: \(traceId)")
        return true
    }

    public func release(traceId: String = "") {
        if !activeTraceId.isEmpty && traceId != activeTraceId {
            ClickyLogger.warning("[RUN_LOCK]", "Ignored release attempt: trace '\(traceId)' does not match active trace '\(activeTraceId)'")
            return
        }
        if lockDepth > 1 {
            lockDepth -= 1
            ClickyLogger.info("[RUN_LOCK]", "Re-entrant lock decremented (remaining depth: \(lockDepth)) for trace: \(traceId)")
            return
        }
        isLocked = false
        activeTraceId = ""
        lockDepth = 0
        lockTimestamp = nil
        ClickyLogger.info("[RUN_LOCK]", "Single-flight lock released for trace: \(traceId)")
    }

    public func isCurrentlyLocked() -> Bool {
        let now = Date()
        if isLocked, let ts = lockTimestamp, now.timeIntervalSince(ts) > timeoutInterval {
            isLocked = false
            activeTraceId = ""
            lockDepth = 0
            lockTimestamp = nil
            return false
        }
        return isLocked
    }
}

@MainActor
public final class TradingViewActionDispatcher {
    public static let shared = TradingViewActionDispatcher()
    public static var soundEffectHandler: ((_ effect: String) -> Void)?

    public static let bundleIdentifier = TradingViewInputSupport.bundleIdentifier
    public static let appPath = TradingViewInputSupport.appPath

    private init() {}

    // MARK: - Market Session Evaluation (Node 02 & DST-Resilient Dynamic TZDB)

    public typealias MarketSession = ClickyFoundation.MarketSession

    public nonisolated static func getCurrentMarketSession(date: Date = Date()) -> MarketSession {
        MarketSession.current(date: date)
    }

    // MARK: - Broker / Order Panel Pre-check (Node 03 Safety Invariant)
    // Note: Best-effort WindowServer title scan. Web-rendered DOM panels inside TradingView
    // may not always instantiate separate macOS NSWindows.

    public static func isOrderPanelActive(simulatedWindowTitles: [String]? = nil) -> Bool {
        if let simulated = simulatedWindowTitles {
            for title in simulated {
                let lower = title.lowercased()
                if lower.contains("order panel") || lower.contains("broker") || lower.contains("buy / sell") || lower.contains("dom") || lower.contains("paper trading") {
                    return true
                }
            }
            return false
        }

        let options = CGWindowListOption(arrayLiteral: .excludeDesktopElements)
        guard let infoList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return false
        }
        for info in infoList {
            let ownerName = info[kCGWindowOwnerName as String] as? String ?? ""
            let windowName = (info[kCGWindowName as String] as? String ?? "").lowercased()
            if ownerName.contains("TradingView") {
                if windowName.contains("order panel") || windowName.contains("broker") || windowName.contains("buy / sell") || windowName.contains("dom") || windowName.contains("paper trading") {
                    return true
                }
            }
        }
        return false
    }

    // MARK: - Master Dispatcher

    @discardableResult
    public func execute(action: TradingViewActionPayload, traceId: String = UUID().uuidString) async -> Bool {
        // 0. Single-Flight Concurrency Run-Lock (Node 01 Invariant)
        let acquired = await FuturesScoutRunLock.shared.tryAcquire(traceId: traceId)
        guard acquired else {
            ClickyLogger.error("[RUN_LOCK]", "Rejected execution: CUA single-flight run-lock active for another trace")
            return false
        }
        let result = await executeInternal(action: action, traceId: traceId)
        await FuturesScoutRunLock.shared.release(traceId: traceId)
        return result
    }

    private func executeInternal(action: TradingViewActionPayload, traceId: String) async -> Bool {
        ClickyLogger.info("[TRADINGVIEW]", "Starting execution for action: \(action.actionType.rawValue), details: \(action.rawDetails)")

        // 0. Pre-Flight Session Guarantee: Ensure CUA session is alive and agent cursor enabled
        await CuaDriverClient.shared.ensureSessionActive()

        // 1. Safety Invariant Pre-check: Reject CUA if Order Panel or Broker Connection is active
        if Self.isOrderPanelActive() {
            ClickyLogger.error("[TRADINGVIEW_SECURITY]", "VETO: CUA action rejected because Order Panel or Broker Connection is active in TradingView")
            return false
        }

        // 2. Ensure TradingView is running, frontmost, and ready in WindowServer
        guard await TradingViewInputSupport.activateTradingView() != nil,
              await TradingViewInputSupport.waitForTradingViewReady(timeout: 2.0) else {
            ClickyLogger.error("[TRADINGVIEW]", "Failed to activate or wait for ready TradingView.app (timeout 2.0s)")
            return false
        }

        var success = false
        switch action.actionType {
        case .chain:
            if let subActions = action.subActions, !subActions.isEmpty {
                ClickyLogger.info("[TRADINGVIEW]", "Executing chained action sequence with \(subActions.count) steps")
                for (idx, sub) in subActions.enumerated() {
                    ClickyLogger.info("[TRADINGVIEW]", "Executing chain step #\(idx + 1)/\(subActions.count): \(sub.actionType.rawValue)")
                    let stepOk = await executeInternal(action: sub, traceId: traceId)
                    if !stepOk {
                        ClickyLogger.error("[TRADINGVIEW]", "Chain ABORTED at step #\(idx + 1) (\(sub.actionType.rawValue)): action returned failure")
                        return false // Abort-on-Failure: do not continue executing following steps
                    }
                    try? await Task.sleep(for: .milliseconds(350))
                }
                success = true
            } else {
                success = true
            }

        case .setupWorkspace:
            success = await TradingViewLayoutTool.shared.setupWorkspace(symbol: action.parameter)

        case .timeframe:
            if let tf = action.parameter {
                success = await TradingViewNavigationTool.shared.switchTimeframe(tf)
            }

        case .symbol:
            if let sym = action.parameter {
                success = await TradingViewNavigationTool.shared.switchSymbol(sym)
            }

        case .resetScale:
            success = await TradingViewLayoutTool.shared.resetChartScale()

        case .toggleSidebar:
            success = await TradingViewLayoutTool.shared.toggleSidebar()

        case .maximize:
            success = await TradingViewLayoutTool.shared.maximizeWindow()

        case .closeModal:
            success = await TradingViewLayoutTool.shared.dismissActiveModals()

        case .selectTool:
            if let tool = action.toolName ?? action.parameter {
                success = await TradingViewDrawingTool.shared.selectToolViaPalette(tool)
            }

        case .drawPoints:
            if let pts = action.points, !pts.isEmpty {
                success = await TradingViewDrawingTool.shared.executeDrawPoints(pts)
            }

        case .drawWithTool:
            if let tool = action.toolName ?? action.parameter {
                success = await TradingViewDrawingTool.shared.drawWithTool(tool, points: action.points)
            }

        case .clearDrawings:
            success = await TradingViewDrawingTool.shared.clearDrawings()

        case .addIndicator:
            if let ind = action.parameter ?? action.toolName {
                success = await addIndicator(ind)
            }

        case .injectPineScript:
            if let script = action.pineScript ?? action.parameter {
                success = await injectPineScript(script)
            }
        }

        if success {
            Self.soundEffectHandler?("done")
            ClickyLogger.success("[TRADINGVIEW]", "Completed action: \(action.actionType.rawValue)")
        } else {
            ClickyLogger.warning("[TRADINGVIEW]", "Action completed with partial/unverified status: \(action.actionType.rawValue)")
        }

        return success
    }

    // MARK: - Backward-Compatible Facade Accessors

    @discardableResult
    public func switchTimeframe(_ tf: String) async -> Bool {
        await execute(action: TradingViewActionPayload(actionType: .timeframe, parameter: tf))
    }

    @discardableResult
    public func switchSymbol(_ sym: String) async -> Bool {
        await execute(action: TradingViewActionPayload(actionType: .symbol, parameter: sym))
    }

    @discardableResult
    public func toggleSidebar() async -> Bool {
        await execute(action: TradingViewActionPayload(actionType: .toggleSidebar))
    }

    @discardableResult
    public func maximizeWindow() async -> Bool {
        await execute(action: TradingViewActionPayload(actionType: .maximize))
    }

    @discardableResult
    public func resetChartScale() async -> Bool {
        await execute(action: TradingViewActionPayload(actionType: .resetScale))
    }

    public func focusChartCanvas() async {
        await TradingViewLayoutTool.shared.focusChartCanvas()
    }

    @discardableResult
    public func clearDrawings() async -> Bool {
        await execute(action: TradingViewActionPayload(actionType: .clearDrawings))
    }

    @discardableResult
    public func selectToolViaPalette(_ tool: String) async -> Bool {
        await execute(action: TradingViewActionPayload(actionType: .selectTool, parameter: tool))
    }

    // MARK: - Indicators & Pine Script Tools

    public func addIndicator(_ indicatorName: String) async -> Bool {
        let clean = indicatorName.trimmingCharacters(in: .whitespacesAndNewlines)
        ClickyLogger.info("[TRADINGVIEW]", "Adding indicator: \(clean)")

        GlobalPushToTalkShortcutMonitor.isSynthesizingInput = true
        defer {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                GlobalPushToTalkShortcutMonitor.isSynthesizingInput = false
            }
        }

        guard TradingViewInputSupport.pressKey(CGKeyCode(kVK_ANSI_Slash)) else {
            ClickyLogger.error("[TRADINGVIEW]", "addIndicator failed: slash keypress rejected")
            return false
        }
        try? await Task.sleep(for: .milliseconds(250))
        guard TradingViewInputSupport.typeStringSlowly(clean) else {
            ClickyLogger.error("[TRADINGVIEW]", "addIndicator failed: typing string rejected")
            return false
        }
        try? await Task.sleep(for: .milliseconds(350))
        guard TradingViewInputSupport.pressKey(CGKeyCode(kVK_Return)) else {
            ClickyLogger.error("[TRADINGVIEW]", "addIndicator failed: return keypress rejected")
            return false
        }
        try? await Task.sleep(for: .milliseconds(200))
        _ = TradingViewInputSupport.pressKey(CGKeyCode(kVK_Escape))
        try? await Task.sleep(for: .milliseconds(150))
        return true
    }

    public func injectPineScript(_ script: String) async -> Bool {
        ClickyLogger.info("[TRADINGVIEW]", "Starting verified Pine Script injection (Option 2 Canon)...")

        guard await TradingViewInputSupport.activateTradingView() != nil else {
            ClickyLogger.error("[TRADINGVIEW]", "injectPineScript: TradingView is not running or cannot be activated")
            return false
        }
        try? await Task.sleep(for: .milliseconds(150))

        GlobalPushToTalkShortcutMonitor.isSynthesizingInput = true
        defer {
            GlobalPushToTalkShortcutMonitor.isSynthesizingInput = false
            TradingViewInputSupport.isPineScriptBackupActive = false
        }

        let pasteboard = NSPasteboard.general
        let originalClipboard = pasteboard.string(forType: .string)

        // 1. Ensure any lingering popups or active dialogs are dismissed
        TradingViewInputSupport.pressKey(CGKeyCode(kVK_Escape))
        try? await Task.sleep(for: .milliseconds(80))
        TradingViewInputSupport.pressKey(CGKeyCode(kVK_Escape))
        try? await Task.sleep(for: .milliseconds(100))

        // 2. Open Pine Editor via Multi-Strategy Opener (P2 Canon)
        let openResult = await openPineEditorPanel()
        guard openResult.isOpen else {
            ClickyLogger.warning("[TRADINGVIEW]", "Editor Pine tidak dapat dibuka — level tersedia di kartu")
            recoverAndParkCursor(originalClipboard: originalClipboard)
            return false
        }

        let probedText = openResult.bufferText
        ClickyLogger.success("[TRADINGVIEW]", "Verified Pine Editor focus successfully! Buffer size: \(probedText.count) chars (strategy \(openResult.strategyUsed))")

        // 3. Paste New Overlay Script & Compile via Cmd + Return
        pasteboard.clearContents()
        pasteboard.setString(script, forType: .string)
        _ = TradingViewInputSupport.pressKey(CGKeyCode(kVK_ANSI_A), flags: [.maskCommand])
        try? await Task.sleep(for: .milliseconds(60))
        _ = TradingViewInputSupport.pressKey(CGKeyCode(kVK_ANSI_V), flags: [.maskCommand])
        try? await Task.sleep(for: .milliseconds(120))

        // Cmd + Return (Add to Chart / Save and Compile in Pine Editor)
        let compiled = TradingViewInputSupport.pressKey(CGKeyCode(kVK_Return), flags: [.maskCommand])
        ClickyLogger.info("[TRADINGVIEW]", "Compiled Pine Script overlay via Cmd+Return (success: \(compiled))")
        try? await Task.sleep(for: .milliseconds(400))

        // Post-Compile Verification: dismiss any compilation tooltip / ensure clean focus
        TradingViewInputSupport.pressKey(CGKeyCode(kVK_Escape))
        try? await Task.sleep(for: .milliseconds(100))

        // 5. Non-Destructive Restoration: If user had an existing legitimate script, restore it
        let trimmedOld = probedText.trimmingCharacters(in: .whitespacesAndNewlines)
        if Self.isLegitimatePineScript(trimmedOld) {
            ClickyLogger.info("[TRADINGVIEW]", "Restoring user's legitimate previous Pine Script buffer (non-destructive)")
            pasteboard.clearContents()
            pasteboard.setString(probedText, forType: .string)
            _ = TradingViewInputSupport.pressKey(CGKeyCode(kVK_ANSI_A), flags: [.maskCommand])
            try? await Task.sleep(for: .milliseconds(60))
            _ = TradingViewInputSupport.pressKey(CGKeyCode(kVK_ANSI_V), flags: [.maskCommand])
            try? await Task.sleep(for: .milliseconds(100))
        } else {
            ClickyLogger.info("[TRADINGVIEW]", "User buffer contained non-script noise or was empty (size \(trimmedOld.count) chars); skipping restore to preserve clean editor")
        }

        // 6. Dismiss/Auto-Close Pine Editor panel to maximize chart canvas view (Opsi 1 Canon)
        await closePineEditorPanel(strategyUsed: openResult.strategyUsed)

        // 7. Synchronous Clipboard Restoration (Node 09 Invariant)
        if let orig = originalClipboard {
            pasteboard.clearContents()
            pasteboard.setString(orig, forType: .string)
            ClickyLogger.info("[TRADINGVIEW]", "Synchronously restored user clipboard")
        }

        return true
    }

    // MARK: - Legitimate Pine Script Filter (Noise / Stray Character Guard)

    /// Determines whether a text string contains legitimate Pine Script code or is just stray noise/text.
    public static func isLegitimatePineScript(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 15 else { return false }
        if trimmed.contains("Izanotchy Fibonacci Overlay") { return false }
        let pineKeywords = [
            "//@version", "indicator(", "strategy(", "study(", "plot(",
            "var ", "box.new", "line.new", "color.", "ta.", "input."
        ]
        return pineKeywords.contains { trimmed.contains($0) }
    }

    // MARK: - Grounded Multi-Strategy Pine Editor Opener (CuaVisualGrounder Canon)

    /// Attempts to open the Pine Editor panel using dynamic visual grounding.
    /// Zero hardcoded (x, y) coordinates — strictly asserts visual presence before any interaction.
    /// Strictly fail-closed: if Pine Editor cannot be visually confirmed, returns (false, "", -1)
    /// to guarantee zero canvas text box pollution.
    public func openPineEditorPanel() async -> (isOpen: Bool, bufferText: String, strategyUsed: Int) {
        guard let winInfo = TradingViewInputSupport.getTradingViewMainWindowInfo() else {
            ClickyLogger.error("[TRADINGVIEW_SECURITY]", "openPineEditorPanel failed: window info unavailable")
            return (false, "", -1)
        }
        let bounds = winInfo.bounds

        // Pre-dismiss any active modals / palettes
        TradingViewInputSupport.pressKey(CGKeyCode(kVK_Escape))
        try? await Task.sleep(for: .milliseconds(60))
        TradingViewInputSupport.pressKey(CGKeyCode(kVK_Escape))
        try? await Task.sleep(for: .milliseconds(80))

        // Check if Pine Editor is ALREADY visually open on screen
        let pid = TradingViewInputSupport.tradingViewPID
        var snapW: CGFloat = bounds.width * 1.36
        var snapH: CGFloat = bounds.height * 1.36
        let preSnapPath = "/tmp/tv_snap_pine_pre.png"
        if let p = pid,
           let snap = try? await CuaDriverClient.shared.captureWindowSnapshot(pid: p, windowId: Int64(winInfo.windowId), outPath: preSnapPath) {
            snapW = snap.width
            snapH = snap.height
        }

        if let grounded = TradingViewVisualGrounder.groundPineEditor(windowId: winInfo.windowId, windowBounds: bounds) {
            ClickyLogger.success("[TRADINGVIEW]", "Pine Editor is already open! Grounded at \(grounded.centerPoint)")
            if let p = pid {
                let gPxX = ((grounded.centerPoint.x - bounds.origin.x) / bounds.width) * snapW
                let gPxY = ((grounded.centerPoint.y - bounds.origin.y) / bounds.height) * snapH
                _ = try? await CuaDriverClient.shared.moveCursor(pid: p, windowId: Int64(winInfo.windowId), x: gPxX, y: gPxY)
                _ = try? await CuaDriverClient.shared.clickPixel(pid: p, windowId: Int64(winInfo.windowId), x: gPxX, y: gPxY)
            } else {
                TradingViewInputSupport.clickMouseDirectly(at: grounded.centerPoint, restoreUserCursor: true)
            }
            try? await Task.sleep(for: .milliseconds(150))
            let probe = await probePineEditorBuffer()
            if probe.isValid {
                return (true, probe.text, 0)
            }
        }

        // Strategy: Open via Command Palette (Cmd + K -> "Pine Editor" -> Visual Click & Down Arrow Selection -> Return)
        ClickyLogger.info("[TRADINGVIEW]", "Opening Pine Editor via Command Palette (Cmd+K)...")
        if TradingViewInputSupport.pressKey(CGKeyCode(kVK_ANSI_K), flags: [.maskCommand]) {
            try? await Task.sleep(for: .milliseconds(250))
            let pb = NSPasteboard.general
            pb.clearContents()
            pb.setString("Pine Editor", forType: .string)
            _ = TradingViewInputSupport.pressKey(CGKeyCode(kVK_ANSI_V), flags: [.maskCommand])
            try? await Task.sleep(for: .milliseconds(300))

            // Visual Click on Search Result Row:
            // In TradingView Command Palette, search result rows appear below search input field.
            // Result row 1 is located around horizontal center, Y ~ 28-32% of window snapshot.
            if let p = pid {
                let searchResultRowPxX = snapW * 0.50
                let searchResultRowPxY = snapH * 0.28
                ClickyLogger.info("[TRADINGVIEW]", "Moving native Cua-Driver cursor to Command Palette 'Pine Editor' result row at (\(Int(searchResultRowPxX)), \(Int(searchResultRowPxY)))")
                _ = try? await CuaDriverClient.shared.moveCursor(pid: p, windowId: Int64(winInfo.windowId), x: searchResultRowPxX, y: searchResultRowPxY)
                try? await Task.sleep(for: .milliseconds(120))
                _ = try? await CuaDriverClient.shared.clickPixel(pid: p, windowId: Int64(winInfo.windowId), x: searchResultRowPxX, y: searchResultRowPxY)
                try? await Task.sleep(for: .milliseconds(120))
            }

            // Dual-Confirmation: Press Down Arrow to highlight first item in list, then press Return to open
            TradingViewInputSupport.pressKey(CGKeyCode(kVK_DownArrow))
            try? await Task.sleep(for: .milliseconds(120))
            _ = TradingViewInputSupport.pressKey(CGKeyCode(kVK_Return))
            try? await Task.sleep(for: .milliseconds(400))

            // Visually verify if Pine Editor opened
            if let grounded = TradingViewVisualGrounder.groundPineEditor(windowId: winInfo.windowId, windowBounds: bounds) {
                if let p = pid {
                    let gPxX = ((grounded.centerPoint.x - bounds.origin.x) / bounds.width) * snapW
                    let gPxY = ((grounded.centerPoint.y - bounds.origin.y) / bounds.height) * snapH
                    _ = try? await CuaDriverClient.shared.moveCursor(pid: p, windowId: Int64(winInfo.windowId), x: gPxX, y: gPxY)
                    _ = try? await CuaDriverClient.shared.clickPixel(pid: p, windowId: Int64(winInfo.windowId), x: gPxX, y: gPxY)
                } else {
                    TradingViewInputSupport.clickMouseDirectly(at: grounded.centerPoint, restoreUserCursor: true)
                }
                try? await Task.sleep(for: .milliseconds(150))
                let probe = await probePineEditorBuffer()
                if probe.isValid {
                    ClickyLogger.success("[TRADINGVIEW]", "Pine Editor opened and focused via Command Palette!")
                    return (true, probe.text, 3)
                }
            }
        }

        // STRICT FAIL-CLOSED VETO: Never click blind coordinates on chart canvas!
        ClickyLogger.warning("[TRADINGVIEW_SECURITY]", "VETO: Pine Editor could not be visually confirmed on screen. Aborting injection to prevent canvas drawing pollution.")
        return (false, "", -1)
    }

    // MARK: - Auto-Close / Minimize Pine Editor Panel (Opsi 1 Canon)

    public func closePineEditorPanel(strategyUsed: Int) async {
        guard let bounds = TradingViewInputSupport.getTradingViewWindowBounds(),
              let winInfo = TradingViewInputSupport.getTradingViewMainWindowInfo(),
              TradingViewInputSupport.isTradingViewFrontmost() else {
            return
        }

        ClickyLogger.info("[TRADINGVIEW]", "Auto-closing Pine Editor panel via native Cua-Driver cursor...")
        let pid = TradingViewInputSupport.tradingViewPID
        
        var snapW: CGFloat = bounds.width * 1.36
        var snapH: CGFloat = bounds.height * 1.36
        let closeSnapPath = "/tmp/tv_snap_pine_close.png"
        if let p = pid,
           let snap = try? await CuaDriverClient.shared.captureWindowSnapshot(pid: p, windowId: Int64(winInfo.windowId), outPath: closeSnapPath) {
            snapW = snap.width
            snapH = snap.height
        }

        // Target close button at top-right of panel header or right dock
        let closeBtn = CGPoint(x: bounds.maxX - 38.0, y: bounds.origin.y + 50.0)
        let cPxX = ((closeBtn.x - bounds.origin.x) / bounds.width) * snapW
        let cPxY = ((closeBtn.y - bounds.origin.y) / bounds.height) * snapH

        if let p = pid {
            _ = try? await CuaDriverClient.shared.moveCursor(pid: p, windowId: Int64(winInfo.windowId), x: cPxX, y: cPxY)
            try? await Task.sleep(for: .milliseconds(100))
            _ = try? await CuaDriverClient.shared.clickPixel(pid: p, windowId: Int64(winInfo.windowId), x: cPxX, y: cPxY)
        } else {
            TradingViewInputSupport.clickMouseDirectly(at: closeBtn, restoreUserCursor: true)
        }
        try? await Task.sleep(for: .milliseconds(150))

        // Also clear any lingering focus via Escape
        TradingViewInputSupport.pressKey(CGKeyCode(kVK_Escape))
        try? await Task.sleep(for: .milliseconds(80))

        // If still open, toggle dock tools icon or bottom handle
        if await probePineEditorBuffer().isValid {
            let dockTogglePt = CGPoint(x: bounds.maxX - 22.0, y: bounds.origin.y + 594.0)
            let dPxX = ((dockTogglePt.x - bounds.origin.x) / bounds.width) * snapW
            let dPxY = ((dockTogglePt.y - bounds.origin.y) / bounds.height) * snapH
            if let p = pid {
                _ = try? await CuaDriverClient.shared.moveCursor(pid: p, windowId: Int64(winInfo.windowId), x: dPxX, y: dPxY)
                _ = try? await CuaDriverClient.shared.clickPixel(pid: p, windowId: Int64(winInfo.windowId), x: dPxX, y: dPxY)
            }
        }

        // Crucial: Always defocus from any text editor and restore focus to candlestick chart canvas
        await TradingViewLayoutTool.shared.focusChartCanvas()
    }

    /// Probes the currently focused element using Sentinel + Copy to determine if it is an active code buffer.
    /// Strictly requires visual grounding confirmation of Pine Editor before considering any probe valid.
    private func probePineEditorBuffer() async -> (isValid: Bool, text: String) {
        // Strict Visual Pre-requisite: Pine Editor MUST be visually confirmed on screen
        guard let winInfo = TradingViewInputSupport.getTradingViewMainWindowInfo(),
              TradingViewVisualGrounder.groundPineEditor(windowId: winInfo.windowId, windowBounds: winInfo.bounds) != nil else {
            ClickyLogger.warning("[TRADINGVIEW_SECURITY]", "probePineEditorBuffer rejected: Pine Editor not visually grounded")
            return (false, "")
        }

        let pasteboard = NSPasteboard.general
        let sentinel = "IZANOTCHY_PINE_PROBE_\(UUID().uuidString.prefix(8))"
        pasteboard.clearContents()
        pasteboard.setString(sentinel, forType: .string)

        TradingViewInputSupport.isPineScriptBackupActive = true
        _ = TradingViewInputSupport.pressKey(CGKeyCode(kVK_ANSI_A), flags: [.maskCommand])
        try? await Task.sleep(for: .milliseconds(50))
        _ = TradingViewInputSupport.pressKey(CGKeyCode(kVK_ANSI_C), flags: [.maskCommand])
        TradingViewInputSupport.isPineScriptBackupActive = false

        let changed = await TradingViewInputSupport.pollUntil(timeout: 0.5, interval: 0.05) { @MainActor in
            let cur = pasteboard.string(forType: .string) ?? ""
            return !cur.isEmpty && cur != sentinel
        }

        let probed = pasteboard.string(forType: .string) ?? ""
        if !changed || probed == sentinel || probed.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return (false, "")
        }

        // Guard against Canvas Drawing JSON false-pass
        let isDrawingJSON = probed.contains("\"sources\":[") ||
                             probed.contains("\"id\":\"LineTool") ||
                             probed.hasPrefix("{\"sources\"") ||
                             probed.hasPrefix("[{\"id\"")
        if isDrawingJSON {
            return (false, "")
        }

        return (true, probed)
    }

    // MARK: - Safe Recovery & Neutral Cursor Parking (Node 09 Invariant)

    private func recoverAndParkCursor(originalClipboard: String?) {
        // 1. Send Escape twice to dismiss any floating palette/dialog
        TradingViewInputSupport.pressKey(CGKeyCode(kVK_Escape))
        usleep(50000)
        TradingViewInputSupport.pressKey(CGKeyCode(kVK_Escape))

        // 2. Synchronous user clipboard restoration (Node 09 Invariant)
        if let orig = originalClipboard {
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(orig, forType: .string)
            ClickyLogger.info("[TRADINGVIEW]", "Synchronously restored user clipboard")
        }
    }
}

// MARK: - DomainActionDispatcher Conformance

extension TradingViewActionDispatcher: DomainActionDispatcher {
    public func executeDomainAction(payload: ComputerUseActionPayload) async {
        if let tvPayload = payload.tradingViewPayload {
            _ = await execute(action: tvPayload)
        }
    }
}

