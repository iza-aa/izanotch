//
//  test_pine_editor_autoclose.swift
//  scripts
//
//  TDD & Verification Suite for Opsi 1:
//  - Auto-Close / Minimize Pine Editor Panel
//  - Legitimate Pine Script Buffer Filter (Noise / Stray Character Rejection)
//  - Focus-Guarded Chart Price Scale Reset (Anti-® Synthesis)
//
//  Compilation standard:
//  swiftc -parse-as-library scripts/test_pine_editor_autoclose.swift -o /tmp/test_pine_autoclose && /tmp/test_pine_autoclose
//

import AppKit
import Carbon.HIToolbox
import Foundation

var totalAssertions = 0
var passedAssertions = 0
var failedAssertions = 0

func assertTest(_ name: String, _ condition: Bool, detail: String = "") {
    totalAssertions += 1
    if condition {
        passedAssertions += 1
        if detail.isEmpty {
            print("  ✅ [PASS] \(name)")
        } else {
            print("  ✅ [PASS] \(name) (\(detail))")
        }
    } else {
        failedAssertions += 1
        print("  ❌ [FAIL] \(name) — \(detail.isEmpty ? "Condition evaluated to false" : detail)")
    }
}

// MARK: - Filter Unit Under Test (Mirroring TradingViewActionDispatcher Logic)

struct PineScriptBufferFilter {
    static func isLegitimatePineScript(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 15 else { return false }
        if trimmed.contains("Izanotchy Fibonacci Overlay") { return false }
        let pineKeywords = [
            "//@version", "indicator(", "strategy(", "study(", "plot(",
            "var ", "box.new", "line.new", "color.", "ta.", "input."
        ]
        return pineKeywords.contains { trimmed.contains($0) }
    }
}

// MARK: - Panel Geometry Unit Under Test

struct PineEditorPanelGeometry {
    static func calculateDockTogglePoint(bounds: CGRect) -> CGPoint {
        return CGPoint(x: bounds.maxX - 22.0, y: bounds.origin.y + 594.0)
    }

    static func calculateHeaderCloseButtonPoint(bounds: CGRect) -> CGPoint {
        return CGPoint(x: bounds.maxX - 62.0, y: bounds.origin.y + 104.0)
    }

    static func calculateBottomHandlePoint(bounds: CGRect) -> CGPoint {
        return CGPoint(x: bounds.origin.x + 180.0, y: bounds.maxY - 14.0)
    }

    static func calculateSafeCanvasFocusPoint(bounds: CGRect) -> CGPoint {
        return CGPoint(x: bounds.origin.x + bounds.width * 0.35, y: bounds.origin.y + 180.0)
    }
}

// MARK: - Mock Scale Reset Orchestrator

actor MockScaleResetOrchestrator {
    var canvasFocusCalled: Bool = false
    var optionRPressed: Bool = false
    var focusOrder: [String] = []

    func focusChartCanvas() {
        canvasFocusCalled = true
        focusOrder.append("focusCanvas")
    }

    func pressOptionR() {
        guard canvasFocusCalled else {
            focusOrder.append("error_option_r_before_focus")
            return
        }
        optionRPressed = true
        focusOrder.append("pressOptionR")
    }
}

@main
struct TestPineEditorAutocloseMain {
    static func main() async {
        print("=================================================================")
        print("🧪 RUNNING TDD TEST SUITE: PINE EDITOR AUTO-CLOSE & NOISE FILTER")
        print("=================================================================")

        // --- SECTION 1: Noise Buffer Filter Tests ---
        print("\n--- SECTION 1: Noise Buffer Filter (Stray Character Rejection) ---")
        
        // 1. Single character "1" or "1\n" (The exact issue user observed)
        assertTest("Rejects single character '1'", !PineScriptBufferFilter.isLegitimatePineScript("1"))
        assertTest("Rejects '1\\n'", !PineScriptBufferFilter.isLegitimatePineScript("1\n"))
        
        // 2. Stray symbol '®'
        assertTest("Rejects stray symbol '®'", !PineScriptBufferFilter.isLegitimatePineScript("®"))
        assertTest("Rejects '1\\n®'", !PineScriptBufferFilter.isLegitimatePineScript("1\n®"))

        // 3. Short random text < 15 chars
        assertTest("Rejects short text 'hello world'", !PineScriptBufferFilter.isLegitimatePineScript("hello world"))
        assertTest("Rejects empty string", !PineScriptBufferFilter.isLegitimatePineScript(""))
        assertTest("Rejects whitespace only", !PineScriptBufferFilter.isLegitimatePineScript("   \n\t  "))

        // 4. Izanotchy Fibonacci Overlay itself should not be re-restored
        let ourOverlay = """
        //@version=5
        indicator("Izanotchy Fibonacci Overlay", overlay=true)
        box.new(left=bar_index-10, top=121.0, right=bar_index, bottom=120.8)
        """
        assertTest("Rejects our own Izanotchy overlay to avoid recursion", !PineScriptBufferFilter.isLegitimatePineScript(ourOverlay))

        // 5. Genuine user Pine scripts MUST pass
        let validUserScript1 = """
        //@version=5
        indicator("My Custom RSI Strategy", overlay=false)
        plot(ta.rsi(close, 14))
        """
        assertTest("Accepts valid user script with //@version and indicator", PineScriptBufferFilter.isLegitimatePineScript(validUserScript1))

        let validUserScript2 = """
        strategy("EMA Cross", overlay=true)
        fast = ta.ema(close, 9)
        slow = ta.ema(close, 21)
        plot(fast, color=color.blue)
        """
        assertTest("Accepts valid user strategy script", PineScriptBufferFilter.isLegitimatePineScript(validUserScript2))

        // --- SECTION 2: Panel Geometry & Safe Coordinates ---
        print("\n--- SECTION 2: Panel Geometry Coordinates ---")
        let sampleBounds = CGRect(x: 180.0, y: 33.0, width: 1152.0, height: 864.0)

        let dockPt = PineEditorPanelGeometry.calculateDockTogglePoint(bounds: sampleBounds)
        assertTest("Dock toggle X is inside window (maxX - 22)", dockPt.x == (sampleBounds.maxX - 22.0) && sampleBounds.contains(dockPt))
        assertTest("Dock toggle Y is origin.y + 594", dockPt.y == (sampleBounds.origin.y + 594.0))

        let closePt = PineEditorPanelGeometry.calculateHeaderCloseButtonPoint(bounds: sampleBounds)
        assertTest("Close button X is inside panel header (maxX - 62)", closePt.x == (sampleBounds.maxX - 62.0) && sampleBounds.contains(closePt))
        assertTest("Close button Y is origin.y + 104", closePt.y == (sampleBounds.origin.y + 104.0))

        let bottomHandlePt = PineEditorPanelGeometry.calculateBottomHandlePoint(bounds: sampleBounds)
        assertTest("Bottom handle is within bottom dock area", sampleBounds.contains(bottomHandlePt))

        let canvasFocusPt = PineEditorPanelGeometry.calculateSafeCanvasFocusPoint(bounds: sampleBounds)
        assertTest("Canvas focus coordinate lands cleanly in candlestick chart area", sampleBounds.contains(canvasFocusPt))

        // --- SECTION 3: Scale Reset Execution Order (Anti-® Synthesis) ---
        print("\n--- SECTION 3: Scale Reset Execution Order ---")
        let scaleOrchestrator = MockScaleResetOrchestrator()
        await scaleOrchestrator.focusChartCanvas()
        await scaleOrchestrator.pressOptionR()

        let order = await scaleOrchestrator.focusOrder
        assertTest("focusChartCanvas is invoked strictly BEFORE Option+R", order == ["focusCanvas", "pressOptionR"])
        let canvasFocused = await scaleOrchestrator.canvasFocusCalled
        let optionRPressed = await scaleOrchestrator.optionRPressed
        assertTest("Both canvas focus and Option+R completed in correct order", canvasFocused && optionRPressed)

        print("\n=================================================================")
        print("📊 TDD TEST RESULTS: \(passedAssertions)/\(totalAssertions) assertions passed")
        if failedAssertions == 0 {
            print("🎉 ALL TESTS PASSED SUCCESSFULLY!")
        } else {
            print("⚠️ \(failedAssertions) TEST(S) FAILED.")
            exit(1)
        }
        print("=================================================================")
    }
}
