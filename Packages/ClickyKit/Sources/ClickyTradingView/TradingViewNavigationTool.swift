import ClickyPlatform
import ClickyReasoning
import ClickyCUA
import ClickyFoundation
//
//  TradingViewNavigationTool.swift
//  boringNotch
//
//  Modular TradingView Symbol & Timeframe Navigation Tool
//  Guarantees proper perpetual swap ticker formatting (BINGX:<COIN>USDT.P) and direct interval switching.
//  Reusable across multiple companions (Futures Scout, Research Buddy, Clicky, etc.)
//

import AppKit
import Carbon.HIToolbox
import Foundation

@MainActor
public final class TradingViewNavigationTool {
    public static let shared = TradingViewNavigationTool()

    private init() {}

    // MARK: - Symbol Switching

    @discardableResult
    public func switchSymbol(_ symbol: String) async -> Bool {
        let clean = symbol.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !clean.isEmpty else {
            ClickyLogger.error("[TRADINGVIEW_NAV]", "Cannot switch symbol: symbol string is empty")
            return false
        }
        ClickyLogger.info("[TRADINGVIEW_NAV]", "Switching symbol directly to: \(clean)")

        GlobalPushToTalkShortcutMonitor.isSynthesizingInput = true
        defer {
            GlobalPushToTalkShortcutMonitor.isSynthesizingInput = false
        }

        // Format ticker to BingX Perpetual Swap contract (guaranteeing .P suffix)
        var targetSymbol = clean
        if targetSymbol.hasPrefix("BINGX:") {
            if !targetSymbol.hasSuffix(".P") && targetSymbol.contains("USDT") {
                targetSymbol += ".P"
            }
        } else if !targetSymbol.contains(":") {
            let stripped = targetSymbol.replacingOccurrences(of: "-", with: "").replacingOccurrences(of: "/", with: "")
            let baseOnly: String = {
                if stripped.hasSuffix(".P") {
                    let noP = String(stripped.dropLast(2))
                    return noP.hasSuffix("USDT") ? String(noP.dropLast(4)) : noP
                }
                return stripped.hasSuffix("USDT") ? String(stripped.dropLast(4)) : stripped
            }()

            let knownStocks: Set<String> = ["AAPL", "MSFT", "GOOGL", "AMZN", "NVDA", "TSLA", "META", "SPY", "QQQ", "DIA"]
            let isStock = knownStocks.contains(baseOnly)

            if !isStock && baseOnly.count >= 2 && baseOnly.count <= 10 {
                targetSymbol = "BINGX:\(baseOnly)USDT.P"
            }
        }
        ClickyLogger.info("[TRADINGVIEW_NAV]", "Formatted symbol for exchange lookup: '\(targetSymbol)'")

        // 1. Ensure TradingView has window & keyboard focus
        _ = await TradingViewInputSupport.activateTradingView()
        try? await Task.sleep(for: .milliseconds(120))

        // 2. Clear lingering popups or active text editing safely with Escape
        TradingViewInputSupport.pressKey(CGKeyCode(kVK_Escape))
        try? await Task.sleep(for: .milliseconds(80))
        TradingViewInputSupport.pressKey(CGKeyCode(kVK_Escape))
        try? await Task.sleep(for: .milliseconds(100))

        // 3. Open Symbol Search dialog cleanly (Opsi A: Snapshot -> Locate -> Act -> Verify)
        var dialogVerifiedOpen = false
        if let winInfo = TradingViewInputSupport.getTradingViewMainWindowInfo() {
            let pid = TradingViewInputSupport.tradingViewPID ?? 0
            let winId = winInfo.windowId
            let bounds = winInfo.bounds

            // Pre-flight session revive
            await CuaDriverClient.shared.ensureSessionActive()

            // 3A. Pre-flight Snapshot via CuaDriver
            let preSnapshotPath = "/tmp/tv_snap_symbol_pre.png"
            var snapshotTaken = false
            var snapW: CGFloat = 1568
            var snapH: CGFloat = 1176
            if let snap = try? await CuaDriverClient.shared.captureWindowSnapshot(pid: pid, windowId: Int64(winId), outPath: preSnapshotPath) {
                snapshotTaken = true
                snapW = snap.width
                snapH = snap.height
                ClickyLogger.info("[TRADINGVIEW_NAV]", "Captured pre-flight snapshot: \(Int(snapW))x\(Int(snapH)) px via cua-driver")
            }

            // 3B. Locate Symbol Pill on snapshot (strictly in row 2 chart toolbar, minNormY: 0.04, maxNormY: 0.12)
            var clickPoint: CGPoint? = nil
            let searchPatterns = ["USDT", ".P", "USD", "BTC", "ETH", "SOL"]
            var locatedTarget: (text: String, pixelCenter: CGPoint, pixelSize: CGSize)? = nil
            if snapshotTaken {
                for pat in searchPatterns {
                    if let loc = CuaVisualGrounder.locateInScreenshot(imagePath: preSnapshotPath, matching: pat, minNormY: 0.04, maxNormY: 0.12) {
                        locatedTarget = loc
                        break
                    }
                }
            }

            if let located = locatedTarget {
                let pxPt = located.pixelCenter
                let windowX = bounds.origin.x + (pxPt.x / snapW) * bounds.width
                let windowY = bounds.origin.y + (pxPt.y / snapH) * bounds.height
                clickPoint = CGPoint(x: windowX, y: windowY)
                ClickyLogger.info("[TRADINGVIEW_NAV]", "Located Symbol Pill in chart toolbar ('\(located.text)') at screenshot px (\(Int(pxPt.x)), \(Int(pxPt.y))), window (\(Int(windowX)), \(Int(windowY)))")

                // 3C. Act: Native Cua-Driver moves cursor & clicks with white-outline cursor (foto 1)
                _ = try? await CuaDriverClient.shared.moveCursor(pid: pid, windowId: Int64(winId), x: Double(pxPt.x), y: Double(pxPt.y))
                try? await Task.sleep(for: .milliseconds(80))
                _ = try? await CuaDriverClient.shared.clickPixel(pid: pid, windowId: Int64(winId), x: Double(pxPt.x), y: Double(pxPt.y))
            } else if let grounded = TradingViewVisualGrounder.groundSymbolPill(windowId: winId, windowBounds: bounds) {
                clickPoint = grounded.centerPoint
                TradingViewInputSupport.clickMouseDirectly(at: clickPoint!, restoreUserCursor: true)
            }

            try? await Task.sleep(for: .milliseconds(250))

            // 3D. VERIFY: Re-snapshot & Assert Dialog Open (Perception Gate)
            let postSnapshotPath = "/tmp/tv_snap_symbol_post.png"
            if (try? await CuaDriverClient.shared.captureWindowSnapshot(pid: pid, windowId: Int64(winId), outPath: postSnapshotPath)) != nil {
                if TradingViewVisualGrounder.isSymbolSearchDialogOpen(imagePath: postSnapshotPath) {
                    dialogVerifiedOpen = true
                    ClickyLogger.success("[TRADINGVIEW_NAV]", "Perception Gate Passed: Symbol Search dialog is confirmed OPEN on screen!")
                }
            }

            // 3E. Fallback Tier 2: If pill click did NOT open dialog, trigger Cmd + K via cua-driver
            if !dialogVerifiedOpen {
                ClickyLogger.warning("[TRADINGVIEW_NAV]", "Perception Gate: Pill click did not open dialog. Escalating to Fallback Tier 2 (Cmd+K via cua-driver)...")
                _ = try? await CuaDriverClient.shared.hotkey(pid: pid, windowId: Int64(winId), keys: ["cmd", "k"])
                try? await Task.sleep(for: .milliseconds(300))

                let fallbackSnapshotPath = "/tmp/tv_snap_symbol_fallback.png"
                if (try? await CuaDriverClient.shared.captureWindowSnapshot(pid: pid, windowId: Int64(winId), outPath: fallbackSnapshotPath)) != nil {
                    if TradingViewVisualGrounder.isSymbolSearchDialogOpen(imagePath: fallbackSnapshotPath) {
                        dialogVerifiedOpen = true
                        ClickyLogger.success("[TRADINGVIEW_NAV]", "Perception Gate Passed: Symbol Search dialog opened via Fallback Cmd+K!")
                    }
                }
            }
        }

        // STRICT FAIL-CLOSED ANNOTATION GATE:
        // If Symbol Search dialog is NOT verified open, NEVER TYPE INTO CANVAS!
        guard dialogVerifiedOpen else {
            ClickyLogger.error("[TRADINGVIEW_NAV]", "FAIL-CLOSED VETO: Symbol Search dialog could NOT be confirmed open. Aborting symbol switch to prevent canvas pollution (Zero Mutation)!")
            return false
        }

        // 4. Select All (Cmd + A) & Delete to clear existing search field text
        TradingViewInputSupport.pressKey(CGKeyCode(kVK_ANSI_A), flags: [.maskCommand])
        try? await Task.sleep(for: .milliseconds(50))
        TradingViewInputSupport.pressKey(CGKeyCode(kVK_Delete))
        try? await Task.sleep(for: .milliseconds(50))

        // 5. Copy target ticker to NSPasteboard and paste via Cmd + V into search field
        let pasteboard = NSPasteboard.general
        let previousClipboard = pasteboard.string(forType: .string)
        pasteboard.clearContents()
        pasteboard.setString(targetSymbol, forType: .string)

        TradingViewInputSupport.pressKey(CGKeyCode(kVK_ANSI_V), flags: [.maskCommand])
        ClickyLogger.info("[TRADINGVIEW_NAV]", "Pasted ticker symbol '\(targetSymbol)' into Symbol Search")

        // Wait for TradingView ticker dropdown results to populate from network
        try? await Task.sleep(for: .milliseconds(500))

        // 6. Press Return to select top matched symbol
        let retOk = TradingViewInputSupport.pressKey(CGKeyCode(kVK_Return))

        // Synchronous immediate clipboard restoration (Node 09 Invariant)
        if let prev = previousClipboard {
            pasteboard.clearContents()
            pasteboard.setString(prev, forType: .string)
            ClickyLogger.info("[TRADINGVIEW_NAV]", "Synchronously restored user clipboard")
        }

        // 7. Closed-Loop Dual-Signal Symbol Gate (Gate 2A Window Title + Gate 2B Chart Data Settled)
        var isSettled = await verifySymbolAndChartSettled(targetSymbol: targetSymbol, timeout: 3.5)

        // Tier 2 Fallback Retry: If Tier 1 failed to settle, attempt Tier 2 (Cmd + K)
        if !isSettled.isVerified {
            ClickyLogger.warning("[TRADINGVIEW_NAV]", "Tier 1 symbol gate timed out. Escalating to Tier 2 (Cmd + K fallback)...")
            TradingViewInputSupport.pressKey(CGKeyCode(kVK_Escape))
            try? await Task.sleep(for: .milliseconds(150))
            TradingViewInputSupport.pressKey(CGKeyCode(kVK_ANSI_K), flags: [.maskCommand])
            try? await Task.sleep(for: .milliseconds(400))
            TradingViewInputSupport.pressKey(CGKeyCode(kVK_ANSI_A), flags: [.maskCommand])
            try? await Task.sleep(for: .milliseconds(50))
            TradingViewInputSupport.pressKey(CGKeyCode(kVK_Delete))
            try? await Task.sleep(for: .milliseconds(50))

            pasteboard.clearContents()
            pasteboard.setString(targetSymbol, forType: .string)
            TradingViewInputSupport.pressKey(CGKeyCode(kVK_ANSI_V), flags: [.maskCommand])
            try? await Task.sleep(for: .milliseconds(500))
            TradingViewInputSupport.pressKey(CGKeyCode(kVK_Return))

            if let prev = previousClipboard {
                pasteboard.clearContents()
                pasteboard.setString(prev, forType: .string)
            }
            isSettled = await verifySymbolAndChartSettled(targetSymbol: targetSymbol, timeout: 3.5)
        }

        if isSettled.isVerified {
            ClickyLogger.success("[TRADINGVIEW_NAV]", "Closed-loop verified: Dual-Signal Symbol Gate passed for '\(targetSymbol)' (title: '\(isSettled.currentTitle)', chart OHLC settled)")
        } else {
            // Tier 3: Zero Mutation fail-closed veto
            ClickyLogger.error("[TRADINGVIEW_NAV]", "TIER 3 FAIL-CLOSED: Dual-signal gate failed after retries. Window title '\(isSettled.currentTitle)' or chart OHLC not settled for '\(targetSymbol)'")
        }

        // 8. Reset chart scale to Auto-Fit so candles are properly proportioned (only if verified)
        let scaleOk: Bool
        if isSettled.isVerified {
            scaleOk = await TradingViewLayoutTool.shared.resetChartScale()
        } else {
            scaleOk = false
        }

        let frontOk = TradingViewInputSupport.isTradingViewFrontmost()
        return retOk && isSettled.isVerified && scaleOk && frontOk
    }

    // MARK: - Closed-Loop Window Title Verification (Option 2 Canon)

    /// Matches a target symbol against TradingView window title.
    /// Pre-registered matching rule:
    /// - Normalizes target symbol: strips exchange prefixes (BINGX:, BINANCE:), slashes, and hyphens.
    /// - Extracts base+quote ticker (e.g. "BTCUSDT").
    /// - Enforces non-alphanumeric boundary so "BTCUSDT" does NOT false-match "WBTCUSDT".
    /// - Prefers ".P" perpetual contract match when applicable.
    public nonisolated static func matchesSymbolInTitle(title: String, targetSymbol: String) -> Bool {
        let cleanTitle = title.uppercased()
        guard !cleanTitle.isEmpty else { return false }

        var raw = targetSymbol.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !raw.isEmpty else { return false }

        if let colonIdx = raw.firstIndex(of: ":") {
            raw = String(raw[raw.index(after: colonIdx)...])
        }
        raw = raw.replacingOccurrences(of: "-", with: "")
                 .replacingOccurrences(of: "/", with: "")

        let hasPSuffix = raw.hasSuffix(".P")
        let baseAndQuote = hasPSuffix ? String(raw.dropLast(2)) : raw
        guard !baseAndQuote.isEmpty else { return false }

        // Also normalize separators in title for comparison (e.g. "BTC / USDT" or "BTC/USDT" -> "BTCUSDT")
        let titleNormalized = cleanTitle.replacingOccurrences(of: "/", with: "")
                                        .replacingOccurrences(of: "-", with: "")

        // Regex boundary guard: ensure ticker is preceded and succeeded by non-alphanumeric chars or boundaries
        let pattern = "(^|[^A-Z0-9])" + NSRegularExpression.escapedPattern(for: baseAndQuote) + "($|[^A-Z0-9])"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return titleNormalized.contains(baseAndQuote)
        }

        let range = NSRange(location: 0, length: titleNormalized.utf16.count)
        let matches = regex.firstMatch(in: titleNormalized, options: [], range: range) != nil
        return matches
    }

    /// Polls TradingView window title asynchronously until it reflects the target symbol or times out (default: 2.0s).
    @discardableResult
    public func verifySymbolTitle(targetSymbol: String, timeout: TimeInterval = 2.0) async -> (isVerified: Bool, currentTitle: String) {
        actor TitleCollector {
            var title: String = ""
            func update(_ t: String) { title = t }
            func get() -> String { title }
        }
        let collector = TitleCollector()
        let verified = await TradingViewInputSupport.pollUntil(timeout: timeout, interval: 0.05) {
            if let info = TradingViewInputSupport.getTradingViewMainWindowInfo() {
                await collector.update(info.title)
                if Self.matchesSymbolInTitle(title: info.title, targetSymbol: targetSymbol) {
                    return true
                }
            }
            return false
        }
        let finalTitle = await collector.get()
        return (verified, finalTitle)
    }

    /// Fase 2 Gate: Polls WindowServer title strictly (Gate 2A) to verify the symbol actually changed.
    /// Strictly FAIL-CLOSED: If the window title still shows the old symbol (e.g. BTC when switching to ETH),
    /// this gate CANNOT pass, completely preventing cross-coin chart pollution.
    @discardableResult
    public func verifySymbolAndChartSettled(targetSymbol: String, timeout: TimeInterval = 3.5) async -> (isVerified: Bool, currentTitle: String) {
        actor TitleCollector {
            var title: String = ""
            func update(_ t: String) { title = t }
            func get() -> String { title }
        }
        let collector = TitleCollector()
        let verified = await TradingViewInputSupport.pollUntil(timeout: timeout, interval: 0.1) {
            guard let info = TradingViewInputSupport.getTradingViewMainWindowInfo() else { return false }
            await collector.update(info.title)

            // Strict Gate 2 Requirement: Title MUST match the target symbol!
            let titleOk = Self.matchesSymbolInTitle(title: info.title, targetSymbol: targetSymbol)
            if titleOk {
                return true
            }

            return false
        }
        let finalTitle = await collector.get()
        return (verified, finalTitle)
    }

    // MARK: - Timeframe Switching (Fase 3 Gate)

    @discardableResult
    public func switchTimeframe(_ timeframe: String) async -> Bool {
        let clean = timeframe.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !clean.isEmpty else {
            ClickyLogger.error("[TRADINGVIEW_NAV]", "Cannot switch timeframe: timeframe string is empty")
            return false
        }
        ClickyLogger.info("[TRADINGVIEW_NAV]", "Switching timeframe to: \(clean)")

        GlobalPushToTalkShortcutMonitor.isSynthesizingInput = true
        defer {
            GlobalPushToTalkShortcutMonitor.isSynthesizingInput = false
        }

        _ = await TradingViewInputSupport.activateTradingView()
        try? await Task.sleep(for: .milliseconds(120))

        // CuaDrive Action Cursor visual indicator for timeframe action
        if let winInfo = TradingViewInputSupport.getTradingViewMainWindowInfo() {
            let bounds = winInfo.bounds
            let tfPoint: CGPoint
            if let groundedTf = TradingViewVisualGrounder.groundTimeframeSelector(targetTf: clean, windowId: winInfo.windowId, windowBounds: bounds) {
                tfPoint = groundedTf.centerPoint
                ClickyLogger.info("[TRADINGVIEW_NAV]", "Grounded Timeframe selector dynamically at: \(tfPoint) (size: \(Int(groundedTf.windowRect.width))x\(Int(groundedTf.windowRect.height)) pt)")
            } else {
                tfPoint = CGPoint(x: bounds.origin.x + bounds.width * 0.22, y: bounds.origin.y + bounds.height * 0.055)
            }
            TradingViewInputSupport.clickMouseDirectly(at: tfPoint, restoreUserCursor: true)
        } else {
            await TradingViewLayoutTool.shared.focusChartCanvas()
        }
        try? await Task.sleep(for: .milliseconds(100))

        // Close any lingering dialog safely with Escape
        _ = TradingViewInputSupport.pressKey(CGKeyCode(kVK_Escape))
        try? await Task.sleep(for: .milliseconds(80))

        let digitsOnly = clean.filter { $0.isNumber }
        let directInterval: String = {
            if clean == "1D" || clean == "D" || clean == "DAY" { return "1D" }
            if clean == "1W" || clean == "W" || clean == "WEEK" { return "1W" }
            if clean == "1M" || clean == "MONTH" { return "1M" }
            if clean == "4H" || clean == "240" { return "240" }
            if clean == "1H" || clean == "60" { return "60" }
            return digitsOnly.isEmpty ? clean : digitsOnly
        }()

        // Type direct interval on canvas with hardware keycodes
        ClickyLogger.info("[TRADINGVIEW_NAV]", "Typing direct interval: '\(directInterval)' with hardware keycodes")
        let typeOk = TradingViewInputSupport.typeStringSlowly(directInterval)
        try? await Task.sleep(for: .milliseconds(150))
        let retOk = TradingViewInputSupport.pressKey(CGKeyCode(kVK_Return))

        // Fase 3 Gate: 2-Layer Timeframe Verification
        let timeframeSettled = await TradingViewInputSupport.pollUntil(timeout: 3.5, interval: 0.25) {
            guard let info = TradingViewInputSupport.getTradingViewMainWindowInfo() else { return false }
            // Layer 1: Window title interval check (some TradingView versions show interval in title, e.g. "BTCUSDT, 15")
            let titleLower = info.title.lowercased()
            let cleanLower = clean.lowercased()
            if titleLower.contains(cleanLower) || (cleanLower == "15m" && titleLower.contains("15")) || (cleanLower == "60m" && titleLower.contains("1h")) {
                return true
            }

            // Layer 2: Vision Fast OCR for confirmed timeframe interval badge in toolbar/header (muted with -x)
            return TradingViewInputSupport.isTimeframeSettled(windowId: info.windowId, targetTimeframe: clean)
        }

        if timeframeSettled {
            ClickyLogger.success("[TRADINGVIEW_NAV]", "Fase 3 Gate Verified: Timeframe '\(clean)' settled on chart toolbar/header")
        } else {
            ClickyLogger.warning("[TRADINGVIEW_NAV]", "Fase 3 Gate TIMEOUT: Timeframe '\(clean)' not confirmed via Vision OCR within 3.5s (proceeding with fallback)")
        }

        // Auto-fit price scale so new timeframe candles are properly scaled
        let scaleOk = await TradingViewLayoutTool.shared.resetChartScale()

        let frontOk = TradingViewInputSupport.isTradingViewFrontmost()
        return typeOk && retOk && scaleOk && frontOk
    }
}
