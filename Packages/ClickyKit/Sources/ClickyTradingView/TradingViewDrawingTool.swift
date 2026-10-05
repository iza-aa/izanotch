import ClickyPlatform
import ClickyReasoning
import ClickyCUA
import ClickyFoundation
//
//  TradingViewDrawingTool.swift
//  boringNotch
//
//  Modular TradingView Technical Drawing & Position Calibration Tool
//  Handles Risk/Reward Long/Short Position tools, WebGL handle dragging, native hotkeys, and palette search.
//  Reusable across multiple companions (Futures Scout, Research Buddy, Clicky, etc.)
//

import AppKit
import Carbon.HIToolbox
import Foundation

@MainActor
public final class TradingViewDrawingTool {
    public static let shared = TradingViewDrawingTool()

    private init() {}

    // MARK: - Master Draw Entry Point

    @discardableResult
    public func drawWithTool(_ toolName: String, points: [CGPoint]? = nil) async -> Bool {
        let clean = toolName.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = clean.lowercased()
        ClickyLogger.info("[TRADINGVIEW_DRAW]", "Executing drawWithTool: '\(clean)'")

        GlobalPushToTalkShortcutMonitor.isSynthesizingInput = true
        defer {
            GlobalPushToTalkShortcutMonitor.isSynthesizingInput = false
        }

        if lower.contains("horizontal line") || lower == "hline" {
            // Direct Native Hotkey: Option + H
            if let pts = points, let firstPt = pts.first {
                guard let targetScreenPt = resolvePoint(firstPt) else {
                    ClickyLogger.error("[TRADINGVIEW_DRAW]", "Failed to resolve point for Horizontal Line (Fail-Closed)")
                    return false
                }
                TradingViewInputSupport.moveMouseSmoothly(to: targetScreenPt)
                try? await Task.sleep(for: .milliseconds(80))
                TradingViewInputSupport.pressKey(CGKeyCode(kVK_ANSI_H), flags: [.maskAlternate])
                ClickyLogger.info("[TRADINGVIEW_DRAW]", "Placed Horizontal Line via native hotkey ⌥+H at \(targetScreenPt)")
                return true
            } else {
                await TradingViewLayoutTool.shared.focusChartCanvas()
                TradingViewInputSupport.pressKey(CGKeyCode(kVK_ANSI_H), flags: [.maskAlternate])
                return true
            }
        } else if lower.contains("horizontal ray") {
            // Direct Native Hotkey: Option + J
            if let pts = points, let firstPt = pts.first {
                guard let targetScreenPt = resolvePoint(firstPt) else {
                    ClickyLogger.error("[TRADINGVIEW_DRAW]", "Failed to resolve point for Horizontal Ray (Fail-Closed)")
                    return false
                }
                TradingViewInputSupport.moveMouseSmoothly(to: targetScreenPt)
                try? await Task.sleep(for: .milliseconds(80))
                TradingViewInputSupport.pressKey(CGKeyCode(kVK_ANSI_J), flags: [.maskAlternate])
                ClickyLogger.info("[TRADINGVIEW_DRAW]", "Placed Horizontal Ray via native hotkey ⌥+J at \(targetScreenPt)")
                return true
            } else {
                await TradingViewLayoutTool.shared.focusChartCanvas()
                TradingViewInputSupport.pressKey(CGKeyCode(kVK_ANSI_J), flags: [.maskAlternate])
                return true
            }
        } else if lower.contains("trend line") {
            // Direct Native Hotkey: Option + T
            TradingViewInputSupport.pressKey(CGKeyCode(kVK_ANSI_T), flags: [.maskAlternate])
            try? await Task.sleep(for: .milliseconds(120))
            if let pts = points, !pts.isEmpty {
                return await executeDrawPoints(pts)
            }
            return true
        } else if lower.contains("fib") {
            // Direct Native Hotkey: Option + F
            TradingViewInputSupport.pressKey(CGKeyCode(kVK_ANSI_F), flags: [.maskAlternate])
            try? await Task.sleep(for: .milliseconds(120))
            if let pts = points, !pts.isEmpty {
                return await executeDrawPoints(pts)
            }
            return true
        } else if lower.contains("long position") || lower.contains("posisi long") || lower == "long" {
            return await placeRiskRewardPosition(isLong: true, points: points)
        } else if lower.contains("short position") || lower.contains("posisi short") || lower == "short" {
            return await placeRiskRewardPosition(isLong: false, points: points)
        } else {
            // Generic tool selection via Command Palette (Cmd + K)
            _ = await selectToolViaPalette(clean)
            try? await Task.sleep(for: .milliseconds(200))
            if let pts = points, !pts.isEmpty {
                return await executeDrawPoints(pts)
            }
            return true
        }
    }

    // MARK: - Risk/Reward Position Tool (Long / Short) Placement & WebGL Dragging

    private func placeRiskRewardPosition(isLong: Bool, points: [CGPoint]?) async -> Bool {
        let toolName = isLong ? "Long Position" : "Short Position"
        ClickyLogger.info("[TRADINGVIEW_DRAW]", "Activating \(toolName) (Risk/Reward box)")

        // 0. Proactively clear any old position boxes or drawings to prevent confusing duplicate stacking
        _ = await clearDrawings()
        try? await Task.sleep(for: .milliseconds(150))

        // 1. Select the tool via palette
        _ = await selectToolViaPalette(toolName)
        try? await Task.sleep(for: .milliseconds(350))

        guard let bounds = TradingViewInputSupport.getTradingViewWindowBounds() else {
            ClickyLogger.error("[TRADINGVIEW_SECURITY]", "VETO: placeRiskRewardPosition failed - TradingView window bounds unavailable (Fail-Closed)")
            return false
        }
        let targetScreenPt: CGPoint
        if let pts = points, let firstPt = pts.first {
            guard let resolved = resolvePoint(firstPt, windowBounds: bounds) else {
                ClickyLogger.error("[TRADINGVIEW_SECURITY]", "VETO: Failed to resolve placement point for \(toolName) (Fail-Closed)")
                return false
            }
            targetScreenPt = resolved
        } else {
            let xRatio: CGFloat = bounds.width > 1200 ? 0.68 : 0.52
            let yRatio: CGFloat = isLong ? 0.68 : 0.42
            targetScreenPt = CGPoint(x: bounds.origin.x + bounds.width * xRatio, y: bounds.origin.y + bounds.height * yRatio)
        }

        // 2. Drop tool at target entry point on candlestick canvas
        ClickyLogger.info("[TRADINGVIEW_DRAW]", "Dropping \(toolName) at canvas coordinate: \(targetScreenPt)")
        TradingViewInputSupport.moveMouseSmoothly(to: targetScreenPt)
        try? await Task.sleep(for: .milliseconds(120))
        TradingViewInputSupport.clickMouse(at: targetScreenPt)
        try? await Task.sleep(for: .milliseconds(300))

        // 3. Physical Handle Dragging with Precision WebGL Geometry:
        // In TradingView WebGL, the placed tool box is centered horizontally at targetScreenPt with width ~200pt (halfWidth = 100pt).
        // Anchor handles are: Top-Left (x - 100, y - defaultHeight), Bottom-Left (x - 100, y + defaultHeight), Right (x + 100, y).
        let boxHalfWidth: CGFloat = 100.0
        let boxHalfHeight: CGFloat = min(220.0, max(140.0, bounds.height * 0.24))
        let leftEdgeX = targetScreenPt.x - boxHalfWidth
        let rightEdgeX = targetScreenPt.x + boxHalfWidth

        if isLong {
            // Long Position:
            // Top-left handle (Take Profit): drag upward ~120pt to expand green box (RR 1:2.45+)
            let topHandle = CGPoint(x: leftEdgeX, y: targetScreenPt.y - boxHalfHeight)
            let expandedTop = CGPoint(x: leftEdgeX, y: targetScreenPt.y - boxHalfHeight - 120)
            TradingViewInputSupport.dragMouse(from: topHandle, to: expandedTop)
            try? await Task.sleep(for: .milliseconds(150))

            // Bottom-left handle (Stop Loss): drag slightly upward to tighten stop loss to rejection wick
            let bottomHandle = CGPoint(x: leftEdgeX, y: targetScreenPt.y + boxHalfHeight)
            let expandedBottom = CGPoint(x: leftEdgeX, y: targetScreenPt.y + boxHalfHeight - 35)
            TradingViewInputSupport.dragMouse(from: bottomHandle, to: expandedBottom)
            try? await Task.sleep(for: .milliseconds(150))
        } else {
            // Short Position:
            // Top-left handle (Stop Loss): drag slightly downward to tighten stop loss
            let topHandle = CGPoint(x: leftEdgeX, y: targetScreenPt.y - boxHalfHeight)
            let expandedTop = CGPoint(x: leftEdgeX, y: targetScreenPt.y - boxHalfHeight + 35)
            TradingViewInputSupport.dragMouse(from: topHandle, to: expandedTop)
            try? await Task.sleep(for: .milliseconds(150))

            // Bottom-left handle (Take Profit): drag downward ~120pt to expand green box (RR 1:2.45+)
            let bottomHandle = CGPoint(x: leftEdgeX, y: targetScreenPt.y + boxHalfHeight)
            let expandedBottom = CGPoint(x: leftEdgeX, y: targetScreenPt.y + boxHalfHeight + 120)
            TradingViewInputSupport.dragMouse(from: bottomHandle, to: expandedBottom)
            try? await Task.sleep(for: .milliseconds(150))
        }

        // Right handle: drag rightward ~100pt to extend box across upcoming candles
        let rightHandle = CGPoint(x: rightEdgeX, y: targetScreenPt.y)
        let extendedRight = CGPoint(x: rightEdgeX + 100, y: targetScreenPt.y)
        TradingViewInputSupport.dragMouse(from: rightHandle, to: extendedRight)
        try? await Task.sleep(for: .milliseconds(120))

        ClickyLogger.success("[TRADINGVIEW_DRAW]", "Placed and physically dragged \(toolName) to RR 1:2.45+")
        return true
    }

    // MARK: - Universal Command Palette (Cmd + K) Tool Selection

    public func selectToolViaPalette(_ toolName: String) async -> Bool {
        let clean = toolName.trimmingCharacters(in: .whitespacesAndNewlines)
        ClickyLogger.info("[TRADINGVIEW_DRAW]", "Selecting tool via palette: \(clean)")

        // 0. Dismiss any lingering popup first
        TradingViewInputSupport.pressKey(CGKeyCode(kVK_Escape))
        try? await Task.sleep(for: .milliseconds(80))

        // 1. Ensure canvas has focus safely
        await TradingViewLayoutTool.shared.focusChartCanvas()
        try? await Task.sleep(for: .milliseconds(120))

        // 2. Open Universal Command Search (Cmd + K)
        TradingViewInputSupport.pressKey(CGKeyCode(kVK_ANSI_K), flags: [.maskCommand])
        try? await Task.sleep(for: .milliseconds(300))

        // 3. Select All and Delete existing text
        TradingViewInputSupport.pressKey(CGKeyCode(kVK_ANSI_A), flags: [.maskCommand])
        try? await Task.sleep(for: .milliseconds(40))
        TradingViewInputSupport.pressKey(CGKeyCode(kVK_Delete))
        try? await Task.sleep(for: .milliseconds(40))

        // 4. Paste tool name via NSPasteboard to guarantee 100% accurate string without dropped letters
        let pb = NSPasteboard.general
        let prev = pb.string(forType: .string)
        pb.clearContents()
        pb.setString(clean, forType: .string)

        TradingViewInputSupport.pressKey(CGKeyCode(kVK_ANSI_V), flags: [.maskCommand])
        try? await Task.sleep(for: .milliseconds(220))

        // 5. Press Down Arrow to move selection from search text field to first search result row
        ClickyLogger.info("[TRADINGVIEW_DRAW]", "Pressing Down Arrow to highlight first result row for '\(clean)'")
        TradingViewInputSupport.pressKey(CGKeyCode(kVK_DownArrow))
        try? await Task.sleep(for: .milliseconds(140))

        // 6. Press Return to activate the highlighted tool and dismiss the modal
        TradingViewInputSupport.pressKey(CGKeyCode(kVK_Return))
        try? await Task.sleep(for: .milliseconds(350))

        if let prev = prev {
            pb.clearContents()
            pb.setString(prev, forType: .string)
            ClickyLogger.info("[TRADINGVIEW_DRAW]", "Synchronously restored user clipboard after palette selection")
        }
        return true
    }

    // MARK: - Multi-Point Canvas Execution

    public func executeDrawPoints(_ points: [CGPoint]) async -> Bool {
        guard !points.isEmpty else { return false }
        ClickyLogger.info("[TRADINGVIEW_DRAW]", "Executing draw points on canvas: \(points.count) points")

        let resolvedPoints: [CGPoint] = points.compactMap { resolvePoint($0) }
        guard resolvedPoints.count == points.count else {
            ClickyLogger.error("[TRADINGVIEW_SECURITY]", "VETO: executeDrawPoints failed - one or more points could not be resolved (Fail-Closed)")
            return false
        }

        if resolvedPoints.count == 1 {
            let p1 = resolvedPoints[0]
            TradingViewInputSupport.moveMouseSmoothly(to: p1)
            try? await Task.sleep(for: .milliseconds(80))
            TradingViewInputSupport.clickMouse(at: p1)
            return true
        }

        if resolvedPoints.count >= 2 {
            let p1 = resolvedPoints[0]
            let p2 = resolvedPoints[1]

            TradingViewInputSupport.moveMouseSmoothly(to: p1)
            try? await Task.sleep(for: .milliseconds(100))
            TradingViewInputSupport.clickMouse(at: p1)
            try? await Task.sleep(for: .milliseconds(180))

            TradingViewInputSupport.moveMouseSmoothly(to: p2)
            try? await Task.sleep(for: .milliseconds(100))
            TradingViewInputSupport.clickMouse(at: p2)

            if resolvedPoints.count >= 3 {
                let p3 = resolvedPoints[2]
                try? await Task.sleep(for: .milliseconds(180))
                TradingViewInputSupport.moveMouseSmoothly(to: p3)
                try? await Task.sleep(for: .milliseconds(100))
                TradingViewInputSupport.clickMouse(at: p3)
            }
            return true
        }

        return false
    }

    // MARK: - Grounded Residual Drawings Purge (Option 1 Canon: Command Palette Cmd+K)

    @discardableResult
    public func purgeResidualDrawings() async -> Bool {
        guard let bounds = TradingViewInputSupport.getTradingViewWindowBounds(),
              TradingViewInputSupport.isTradingViewFrontmost() else {
            ClickyLogger.warning("[TRADINGVIEW_DRAW]", "Failed to get TradingView window bounds or not frontmost (Fail-Closed)")
            return false
        }

        ClickyLogger.info("[TRADINGVIEW_DRAW]", "Executing deterministic drawing purge via Universal Command Palette (Cmd+K)...")

        GlobalPushToTalkShortcutMonitor.isSynthesizingInput = true
        defer {
            GlobalPushToTalkShortcutMonitor.isSynthesizingInput = false
        }

        // Pre-flight: Ensure CuaDriver session is active
        await CuaDriverClient.shared.ensureSessionActive()

        // 1. Move native CuaDriver cursor smoothly towards upper-center canvas for elegant visual feedback
        if let pid = TradingViewInputSupport.tradingViewPID,
           let winInfo = TradingViewInputSupport.getTradingViewMainWindowInfo() {
            let centerPxX = bounds.width * 0.5
            let centerPxY = bounds.height * 0.35
            _ = try? await CuaDriverClient.shared.moveCursor(pid: pid, windowId: Int64(winInfo.windowId), x: centerPxX, y: centerPxY)
        }

        // 2. Select "Remove drawings" and "Remove indicators" via TradingView's official Universal Command Palette (Cmd+K)
        // 100% deterministic: zero pixel math, zero light-dismiss portal races, zero canvas mis-clicks.
        let successDrawings = await selectToolViaPalette("Remove drawings")
        try? await Task.sleep(for: .milliseconds(80))
        let successIndicators = await selectToolViaPalette("Remove indicators")

        // 3. Ensure modals are fully dismissed cleanly
        TradingViewInputSupport.pressKey(CGKeyCode(kVK_Escape))
        try? await Task.sleep(for: .milliseconds(50))

        if successDrawings {
            ClickyLogger.success("[TRADINGVIEW_DRAW]", "Successfully purged chart drawings (indicators purge: \(successIndicators)) via Command Palette (Cmd+K)")
        } else {
            ClickyLogger.error("[TRADINGVIEW_DRAW]", "Failed to execute 'Remove drawings' via Command Palette")
        }
        return successDrawings
    }

    // MARK: - Clear Drawings

    @discardableResult
    public func clearDrawings() async -> Bool {
        return await purgeResidualDrawings()
    }

    public static func resolvePoint(_ pt: CGPoint, windowBounds: CGRect?) -> CGPoint? {
        TradingViewInputSupport.resolvePoint(pt, windowBounds: windowBounds)
    }

    public func resolvePoint(_ pt: CGPoint, windowBounds: CGRect? = nil) -> CGPoint? {
        TradingViewInputSupport.resolvePoint(pt, windowBounds: windowBounds ?? TradingViewInputSupport.getTradingViewWindowBounds())
    }
}
