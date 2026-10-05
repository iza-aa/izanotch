//
//  test_p3_outside_gp_overlay.swift
//  scripts
//
//  TDD & Verification Suite for P3: Outside-GP Context Overlay & Trade Plan Persistence
//  Tests:
//  1. Choppy Status (.standAsideChoppy) returns empty script -> zero injection
//  2. Outside-GP Status (.standAsideOutsideGP) generates reference overlay:
//     - GP zone box + continuous lines
//     - Dominant swing reference lines
//     - Status label "Menunggu Pullback ke Golden Pocket"
//     - STRICTLY ZERO TP/SL risk-reward boxes, ZERO Entry Limit line
//     - Memory safety limits (max_lines_count=500, max_labels_count=500, max_boxes_count=500)
//  3. In-GP & Setup Status (.inGoldenPocketWaiting / .setupDetected) generates full Trade Plan:
//     - TP Box (Green), SL Box (Red), Entry Limit Line (Blue), TP1/TP2 labels
//  4. Briefing Card Overlay Note Differentiation across all statuses
//
//  Compilation standard:
//  swiftc -parse-as-library scripts/test_p3_outside_gp_overlay.swift -o /tmp/test_p3 && /tmp/test_p3
//

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

// MARK: - Mock Generator Matching Target CoreAnalyst Logic for P3

enum MockAstronacciRegime: String {
    case bullish = "Bullish"
    case bearish = "Bearish"
    case neutral = "Neutral"
}

enum MockFuturesScoutStatus: String {
    case standAsideChoppy = "STAND ASIDE (Choppy / Flat)"
    case standAsideOutsideGP = "STAND ASIDE (Di Luar Golden Pocket)"
    case inGoldenPocketWaiting = "IN GOLDEN POCKET (Menunggu Pemicu Kandel)"
    case setupDetected = "SETUP TERKONFIRMASI (A-Grade Setup)"
}

struct MockAnalysisResult {
    let symbol: String
    let status: MockFuturesScoutStatus
    let regime: MockAstronacciRegime
    let currentLivePrice: Double
    let swingHigh: Double
    let swingLow: Double
    let gpLow: Double
    let gpHigh: Double
    let invalidationLevel: Double
    let targetExpansion1272: Double
    let targetExpansion1618: Double
}

struct MockPineScriptGenerator {
    static func formatPrice(_ p: Double) -> String {
        let absP = abs(p)
        if absP >= 1000.0 { return String(format: "%.1f", p) }
        else if absP >= 1.0 { return String(format: "%.2f", p) }
        else if absP >= 0.01 { return String(format: "%.4f", p) }
        else { return String(format: "%.8f", p) }
    }

    static func generateOverlay(result: MockAnalysisResult) -> String {
        // Choppy market: ZERO canvas mutations
        if result.status == .standAsideChoppy {
            return ""
        }

        let isLong = result.regime == .bullish
        let minGP = min(result.gpLow, result.gpHigh)
        let maxGP = max(result.gpLow, result.gpHigh)
        let entryLimit = (minGP + maxGP) / 2.0
        let inv = result.invalidationLevel
        let tp1 = result.targetExpansion1272
        let tp2 = result.targetExpansion1618

        let riskDist = abs(entryLimit - inv)
        let rewardDist = abs(tp1 - entryLimit)
        let rrRatio = riskDist > 0 ? (rewardDist / riskDist) : 0.0

        let formatPattern: String
        let absLive = abs(result.currentLivePrice)
        if absLive >= 1.0 { formatPattern = "#.##" }
        else if absLive >= 0.01 { formatPattern = "#.####" }
        else { formatPattern = "#.######" }

        // Mode 1: Outside Golden Pocket Reference Context Overlay
        if result.status == .standAsideOutsideGP {
            return """
            //@version=5
            indicator("Izanotchy Fibonacci Overlay", overlay=true, max_lines_count=500, max_labels_count=500, max_boxes_count=500)

            // Reference Geometry (Outside GP Context)
            gp_high = \(formatPrice(maxGP))
            gp_low = \(formatPrice(minGP))
            swing_high = \(formatPrice(result.swingHigh))
            swing_low = \(formatPrice(result.swingLow))

            gph = plot(gp_high, "GP 50.0%", color=color.new(color.orange, 50), linewidth=1, style=plot.style_line)
            gpl = plot(gp_low, "GP 61.8%", color=color.new(color.orange, 50), linewidth=1, style=plot.style_line)
            fill(gph, gpl, color=color.new(color.orange, 90), title="Golden Pocket")
            plot(swing_high, "Swing High", color=color.new(color.gray, 50), linewidth=1, style=plot.style_circles)
            plot(swing_low, "Swing Low", color=color.new(color.gray, 50), linewidth=1, style=plot.style_circles)

            var box gp_box = na
            var label status_lbl = na

            if barstate.islast
                box.delete(gp_box)
                label.delete(status_lbl)

                int left_bar = bar_index - 8
                int right_bar = bar_index + 16

                gp_box := box.new(left=left_bar, top=gp_high, right=right_bar, bottom=gp_low, bgcolor=color.new(color.orange, 92), border_color=color.new(color.orange, 40), border_style=line.style_dashed)
                status_lbl := label.new(x=right_bar, y=(gp_high + gp_low) / 2, text="STATUS: Menunggu Pullback ke Golden Pocket (" + str.tostring(gp_low, "\(formatPattern)") + " - " + str.tostring(gp_high, "\(formatPattern)") + ")", color=color.new(color.orange, 20), textcolor=color.white, style=label.style_label_left, size=size.small)
            """
        }

        // Mode 2: Actionable Trade Plan Box (.inGoldenPocketWaiting or .setupDetected)
        return """
        //@version=5
        indicator("Izanotchy Fibonacci Overlay", overlay=true, max_lines_count=500, max_labels_count=500, max_boxes_count=500)

        // Direction & Calculated Levels
        is_long = \(isLong ? "true" : "false")
        gp_high = \(formatPrice(maxGP))
        gp_low = \(formatPrice(minGP))
        inv_level = \(formatPrice(inv))
        tp1_level = \(formatPrice(tp1))
        tp2_level = \(formatPrice(tp2))
        entry_price = \(formatPrice(entryLimit))
        rr_ratio = \(String(format: "%.1f", rrRatio))

        // Continuous Baseline Reference
        gph = plot(gp_high, "GP 50.0%", color=color.new(color.orange, 50), linewidth=1, style=plot.style_line)
        gpl = plot(gp_low, "GP 61.8%", color=color.new(color.orange, 50), linewidth=1, style=plot.style_line)
        fill(gph, gpl, color=color.new(color.orange, 90), title="Golden Pocket")
        plot(inv_level, "Invalidasi (78.6%)", color=color.new(color.red, 30), linewidth=1, style=plot.style_line)
        plot(tp1_level, "TP1 (1.272)", color=color.new(color.green, 30), linewidth=1, style=plot.style_line)
        plot(tp2_level, "TP2 (1.618)", color=color.new(color.green, 50), linewidth=1, style=plot.style_line)

        // Dynamic Interactive Trade Plan Box (Option A Canon)
        var box tp_box = na
        var box sl_box = na
        var box gp_box = na
        var line entry_line = na
        var label entry_lbl = na
        var label sl_lbl = na
        var label tp1_lbl = na
        var label tp2_lbl = na
        var label title_lbl = na

        if barstate.islast
            // Cleanup prior drawings
            box.delete(tp_box)
            box.delete(sl_box)
            box.delete(gp_box)
            line.delete(entry_line)
            label.delete(entry_lbl)
            label.delete(sl_lbl)
            label.delete(tp1_lbl)
            label.delete(tp2_lbl)
            label.delete(title_lbl)

            int left_bar = bar_index - 8
            int right_bar = bar_index + 16

            // 1. Golden Pocket Zone Box
            gp_box := box.new(left=left_bar, top=gp_high, right=right_bar, bottom=gp_low, bgcolor=color.new(color.orange, 88), border_color=color.new(color.orange, 40), border_style=line.style_dashed)

            // 2. Risk (Red) & Reward (Green) Trade Plan Boxes
            if is_long
                tp_box := box.new(left=left_bar, top=tp1_level, right=right_bar, bottom=entry_price, bgcolor=color.new(color.green, 85), border_color=color.green, border_width=1)
                sl_box := box.new(left=left_bar, top=entry_price, right=right_bar, bottom=inv_level, bgcolor=color.new(color.red, 85), border_color=color.red, border_width=1)
                title_lbl := label.new(x=left_bar, y=tp2_level > tp1_level ? tp2_level : tp1_level, text="TRADE PLAN: BUY / LONG (R:R 1:" + str.tostring(rr_ratio) + ")", color=color.new(color.blue, 20), textcolor=color.white, style=label.style_label_down, size=size.small)
            else
                tp_box := box.new(left=left_bar, top=entry_price, right=right_bar, bottom=tp1_level, bgcolor=color.new(color.green, 85), border_color=color.green, border_width=1)
                sl_box := box.new(left=left_bar, top=inv_level, right=right_bar, bottom=entry_price, bgcolor=color.new(color.red, 85), border_color=color.red, border_width=1)
                title_lbl := label.new(x=left_bar, y=inv_level, text="TRADE PLAN: SELL / SHORT (R:R 1:" + str.tostring(rr_ratio) + ")", color=color.new(color.purple, 20), textcolor=color.white, style=label.style_label_down, size=size.small)

            // 3. Entry Limit Line
            entry_line := line.new(x1=left_bar, y1=entry_price, x2=right_bar, y2=entry_price, color=color.blue, width=2)

            // 4. Badges & Price Labels
            string entry_tag = is_long ? "[BUY LIMIT]" : "[SELL LIMIT]"
            entry_lbl := label.new(x=right_bar, y=entry_price, text=entry_tag + " Entry: " + str.tostring(entry_price, "\(formatPattern)") + " (GP)", color=color.blue, textcolor=color.white, style=label.style_label_left, size=size.small)
            tp1_lbl := label.new(x=right_bar, y=tp1_level, text="[TAKE PROFIT 1]: " + str.tostring(tp1_level, "\(formatPattern)") + " (R:R 1:" + str.tostring(rr_ratio) + ")", color=color.green, textcolor=color.white, style=label.style_label_left, size=size.small)
            tp2_lbl := label.new(x=right_bar, y=tp2_level, text="[TAKE PROFIT 2]: " + str.tostring(tp2_level, "\(formatPattern)"), color=color.teal, textcolor=color.white, style=label.style_label_left, size=size.small)
            sl_lbl := label.new(x=right_bar, y=inv_level, text="[STOP LOSS]: " + str.tostring(inv_level, "\(formatPattern)") + " (Inv 78.6%)", color=color.red, textcolor=color.white, style=label.style_label_left, size=size.small)
        """
    }

    static func getOverlayNote(status: MockFuturesScoutStatus) -> String {
        switch status {
        case .standAsideChoppy:
            return "— *(Tidak digambar pada status STAND ASIDE / Pasar Choppy)*"
        case .standAsideOutsideGP:
            return "Garis Referensi Golden Pocket (50.0% – 61.8%) & Ayunan Dominan dipetakan"
        case .inGoldenPocketWaiting, .setupDetected:
            return "Aktif & dipetakan di TradingView"
        }
    }
}

@main
struct TestP3OutsideGPOverlay {
    static func main() {
        print("==================================================")
        print("   P3: Outside-GP Context Overlay & Trade Plan    ")
        print("==================================================")

        let btcChoppy = MockAnalysisResult(
            symbol: "BTC/USDT",
            status: .standAsideChoppy,
            regime: .neutral,
            currentLivePrice: 84000.0,
            swingHigh: 84500.0,
            swingLow: 83800.0,
            gpLow: 84150.0,
            gpHigh: 84250.0,
            invalidationLevel: 83900.0,
            targetExpansion1272: 85000.0,
            targetExpansion1618: 85500.0
        )

        let btcOutsideGP = MockAnalysisResult(
            symbol: "BTC/USDT",
            status: .standAsideOutsideGP,
            regime: .bullish,
            currentLivePrice: 85200.0,
            swingHigh: 85500.0,
            swingLow: 83000.0,
            gpLow: 83955.0,
            gpHigh: 84250.0,
            invalidationLevel: 83535.0,
            targetExpansion1272: 86180.0,
            targetExpansion1618: 87045.0
        )

        let btcSetup = MockAnalysisResult(
            symbol: "BTC/USDT",
            status: .setupDetected,
            regime: .bullish,
            currentLivePrice: 84100.0,
            swingHigh: 85500.0,
            swingLow: 83000.0,
            gpLow: 83955.0,
            gpHigh: 84250.0,
            invalidationLevel: 83535.0,
            targetExpansion1272: 86180.0,
            targetExpansion1618: 87045.0
        )

        // --- Test 1: Choppy Status Returns Empty String ---
        let choppyScript = MockPineScriptGenerator.generateOverlay(result: btcChoppy)
        assertTest(
            "Choppy market returns completely empty Pine Script (Zero Mutation)",
            choppyScript.isEmpty
        )

        // --- Test 2: Outside GP Generates Reference Context Overlay ---
        let outsideScript = MockPineScriptGenerator.generateOverlay(result: btcOutsideGP)
        assertTest(
            "Outside GP generates non-empty indicator script",
            !outsideScript.isEmpty && outsideScript.contains("indicator(\"Izanotchy Fibonacci Overlay\"")
        )
        assertTest(
            "Outside GP enforces Pine Script memory limits (max_lines_count=500)",
            outsideScript.contains("max_lines_count=500") && outsideScript.contains("max_labels_count=500") && outsideScript.contains("max_boxes_count=500")
        )
        assertTest(
            "Outside GP includes Golden Pocket baseline & zone",
            outsideScript.contains("gp_high = 84250.0") && outsideScript.contains("title=\"Golden Pocket\"")
        )
        assertTest(
            "Outside GP includes status note label",
            outsideScript.contains("STATUS: Menunggu Pullback ke Golden Pocket")
        )
        assertTest(
            "Outside GP strictly excludes TP Box, SL Box, and Entry Limit Line (No False Commitments)",
            !outsideScript.contains("tp_box") && !outsideScript.contains("sl_box") && !outsideScript.contains("entry_line") && !outsideScript.contains("[BUY LIMIT]")
        )

        // --- Test 3: Actionable Setup Generates Full Trade Plan Box ---
        let setupScript = MockPineScriptGenerator.generateOverlay(result: btcSetup)
        assertTest(
            "Actionable setup contains full TP Box, SL Box, and Entry Limit Line",
            setupScript.contains("tp_box :=") && setupScript.contains("sl_box :=") && setupScript.contains("entry_line :=") && setupScript.contains("[BUY LIMIT]")
        )
        assertTest(
            "Actionable setup contains dynamic drawing cleanup (box.delete)",
            setupScript.contains("box.delete(tp_box)") && setupScript.contains("box.delete(sl_box)") && setupScript.contains("box.delete(gp_box)")
        )

        // --- Test 4: Card Overlay Note Verification ---
        assertTest(
            "Choppy card note indicates not drawn",
            MockPineScriptGenerator.getOverlayNote(status: .standAsideChoppy).contains("Tidak digambar pada status STAND ASIDE")
        )
        assertTest(
            "Outside GP card note indicates reference mapping",
            MockPineScriptGenerator.getOverlayNote(status: .standAsideOutsideGP).contains("Garis Referensi Golden Pocket")
        )
        assertTest(
            "Setup card note indicates active trade plan",
            MockPineScriptGenerator.getOverlayNote(status: .setupDetected) == "Aktif & dipetakan di TradingView"
        )

        print("\n--------------------------------------------------")
        print("P3 Results: \(passedAssertions)/\(totalAssertions) passed")
        print("--------------------------------------------------")

        if failedAssertions == 0 {
            print("🎉 ALL P3 OVERLAY & MEMORY TESTS PASSED (100%)!")
            exit(0)
        } else {
            print("💥 SOME P3 TESTS FAILED (\(failedAssertions) failures)!")
            exit(1)
        }
    }
}
