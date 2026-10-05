import ClickyPlatform
import ClickyReasoning
import ClickyCUA
import ClickyFoundation
//
//  TradingViewVisualGrounder.swift
//  boringNotch
//
//  Specialized Visual Perceptual Engine for TradingView macOS Desktop Application.
//  Encapsulates domain-specific element detection:
//  - Symbol search modal & tab keywords
//  - Pine editor workspace grounding
//  - Top toolbar symbol pill & timeframe interval selector grounding
//

import AppKit
import CoreGraphics
import Foundation
import Vision

public enum TradingViewVisualGrounder {

    // MARK: - Dialog & Modal Verifications

    /// Verifies whether the Symbol Search modal / input dialog is physically open on screen.
    public nonisolated static func isSymbolSearchDialogOpen(imagePath: String) -> Bool {
        guard let imgSource = CGImageSourceCreateWithURL(URL(fileURLWithPath: imagePath) as CFURL, nil),
              let cgImage = CGImageSourceCreateImageAtIndex(imgSource, 0, nil) else { return false }

        let req = VNRecognizeTextRequest()
        req.recognitionLevel = .fast
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try? handler.perform([req])

        guard let results = req.results else { return false }
        let modalHeaders = ["symbol search"]
        let tabKeywords = ["all types", "stocks", "funds", "futures", "forex", "indices", "bonds", "economy"]

        var hasModalHeader = false
        var tabKeywordMatches = 0

        for obs in results {
            guard let top = obs.topCandidates(1).first?.string.lowercased() else { continue }
            for mh in modalHeaders {
                if top.contains(mh) {
                    hasModalHeader = true
                    break
                }
            }
            for tk in tabKeywords {
                if top == tk || top.contains(tk) {
                    tabKeywordMatches += 1
                }
            }
        }
        return hasModalHeader || tabKeywordMatches >= 2
    }

    /// Verifies whether the Pine Editor panel is physically open on screen.
    public nonisolated static func isPineEditorOpenInScreenshot(imagePath: String) -> Bool {
        guard let imgSource = CGImageSourceCreateWithURL(URL(fileURLWithPath: imagePath) as CFURL, nil),
              let cgImage = CGImageSourceCreateImageAtIndex(imgSource, 0, nil) else { return false }

        let req = VNRecognizeTextRequest()
        req.recognitionLevel = .fast
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try? handler.perform([req])

        guard let results = req.results else { return false }
        for obs in results {
            guard let top = obs.topCandidates(1).first?.string else { continue }
            if top.contains("Pine Editor") {
                return true
            }
        }
        return false
    }

    // MARK: - Specialized Element Grounders

    /// Grounds the Symbol Search Pill in the top toolbar (e.g. "[ BTCUSDT.P v ]").
    /// Measures the exact size of the pill and returns its center point.
    public nonisolated static func groundSymbolPill(
        windowId: CGWindowID,
        windowBounds: CGRect
    ) -> GroundedUIElement? {
        let elements = CuaVisualGrounder.extractElements(
            windowId: windowId,
            windowBounds: windowBounds,
            cropNorm: CGRect(x: 0, y: 0.04, width: 0.45, height: 0.08)
        )

        let candidates = elements.filter { elem in
            let upper = elem.text.uppercased()
            return (upper.contains("BTC") || upper.contains("ETH") || upper.contains("SOL") ||
                    upper.contains("USDT") || upper.contains(".P") || upper.contains("/")) &&
                   !upper.contains("BITCOIN/USD TETHER")
        }

        if let pill = candidates.first {
            ClickyLogger.info("[TV_GROUNDER]", "Grounded Symbol Pill: '\(pill.text)', size \(Int(pill.windowRect.width))x\(Int(pill.windowRect.height)) pt -> Center: (\(Int(pill.centerPoint.x)), \(Int(pill.centerPoint.y)))")
            return pill
        }

        ClickyLogger.warning("[TV_GROUNDER]", "Symbol Pill not visually grounded in top toolbar")
        return nil
    }

    /// Grounds the Timeframe Interval Selector in the top toolbar (e.g. "15m", "1h", "5m").
    public nonisolated static func groundTimeframeSelector(
        targetTf: String,
        windowId: CGWindowID,
        windowBounds: CGRect
    ) -> GroundedUIElement? {
        let elements = CuaVisualGrounder.extractElements(
            windowId: windowId,
            windowBounds: windowBounds,
            cropNorm: CGRect(x: 0.10, y: 0, width: 0.40, height: 0.18)
        )

        let cleanTf = targetTf.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let variants: [String] = {
            if cleanTf == "15" || cleanTf == "15m" { return ["15m", "15 m", "15"] }
            if cleanTf == "60" || cleanTf == "1h" || cleanTf == "1" { return ["1h", "1 h", "60m"] }
            if cleanTf == "5" || cleanTf == "5m" { return ["5m", "5 m", "5"] }
            if cleanTf == "d" || cleanTf == "1d" { return ["1d", "1 d", "D"] }
            return [cleanTf]
        }()

        for elem in elements {
            let lower = elem.text.lowercased()
            for v in variants {
                if lower == v || lower.contains(v) {
                    ClickyLogger.info("[TV_GROUNDER]", "Grounded Timeframe Selector: '\(elem.text)' -> Center: (\(Int(elem.centerPoint.x)), \(Int(elem.centerPoint.y)))")
                    return elem
                }
            }
        }

        ClickyLogger.warning("[TV_GROUNDER]", "Timeframe selector '\(targetTf)' not visually grounded")
        return nil
    }

    /// Grounds the Pine Editor header and text region if physically open on screen.
    /// Returns nil if Pine Editor is not confirmed on screen (strictly fail-closed).
    public nonisolated static func groundPineEditor(
        windowId: CGWindowID,
        windowBounds: CGRect
    ) -> GroundedUIElement? {
        let elements = CuaVisualGrounder.extractElements(windowId: windowId, windowBounds: windowBounds)

        guard let header = elements.first(where: { $0.text.contains("Pine Editor") }) else {
            ClickyLogger.warning("[TV_GROUNDER]", "Pine Editor is NOT visually rendered on screen (Fail-Closed)")
            return nil
        }

        let editorCenterX: CGFloat
        let editorCenterY: CGFloat

        if header.centerPoint.x > windowBounds.origin.x + windowBounds.width * 0.5 {
            editorCenterX = header.centerPoint.x
            editorCenterY = header.centerPoint.y + 180.0
        } else {
            editorCenterX = windowBounds.origin.x + windowBounds.width * 0.5
            editorCenterY = min(header.centerPoint.y + 120.0, windowBounds.maxY - 80.0)
        }

        let editorRect = CGRect(x: editorCenterX - 150, y: editorCenterY - 100, width: 300, height: 200)
        let grounded = GroundedUIElement(
            text: "Pine Editor Workspace",
            windowRect: editorRect,
            centerPoint: CGPoint(x: editorCenterX, y: editorCenterY)
        )
        ClickyLogger.success("[TV_GROUNDER]", "Grounded Pine Editor at (\(Int(editorCenterX)), \(Int(editorCenterY)))")
        return grounded
    }
}
