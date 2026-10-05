//
//  test_chart_analyst.swift
//  Unit and Functional Tests for On-Demand Chart Analyst (Option B Canon)
//  Expanded to verify Phase 1: Pure Mathematical Decoupling, Time Engine,
//  Stochastic SSOT, and Clean Audio TTS Contract (Agent 1 & 2 Specification).
//

import AppKit
import Foundation

final class GlobalPushToTalkShortcutMonitor {
    static var isSynthesizingInput: Bool = false
}

@main
struct TestChartAnalystMain {
    static func main() async {
        print("=================================================================")
        print("🧪 UJI FUNGSIONAL & MATEMATIS ON-DEMAND CHART ANALYST (FASE 1 & 2)")
        print("=================================================================")

        // -------------------------------------------------------------
        // 1. Symbol Normalization Tests (Exchange Format)
        // -------------------------------------------------------------
        let btcEx = FuturesScoutMarketDataService.normalizeSymbolForExchange("BTC")
        assert(btcEx == "BTC-USDT", "Expected BTC-USDT, got \(btcEx)")
        print("  ✅ [PASS] Normalisasi Exchange: 'BTC' -> '\(btcEx)'")

        let ethEx = FuturesScoutMarketDataService.normalizeSymbolForExchange("ETHUSDT")
        assert(ethEx == "ETH-USDT", "Expected ETH-USDT, got \(ethEx)")
        print("  ✅ [PASS] Normalisasi Exchange: 'ETHUSDT' -> '\(ethEx)'")

        let solEx = FuturesScoutMarketDataService.normalizeSymbolForExchange("BINANCE:SOLUSDT")
        assert(solEx == "SOL-USDT", "Expected SOL-USDT, got \(solEx)")
        print("  ✅ [PASS] Normalisasi Exchange: 'BINANCE:SOLUSDT' -> '\(solEx)'")

        // -------------------------------------------------------------
        // 2. Symbol Normalization Tests (TradingView Doc 05 Canon Format BINGX:*.P)
        // -------------------------------------------------------------
        let btcTv = FuturesScoutMarketDataService.normalizeSymbolForTradingView("BTC")
        assert(btcTv == "BINGX:BTCUSDT.P", "Expected BINGX:BTCUSDT.P, got \(btcTv)")
        print("  ✅ [PASS] Normalisasi TradingView: 'BTC' -> '\(btcTv)'")

        let btcUsdtTv = FuturesScoutMarketDataService.normalizeSymbolForTradingView("BTCUSDT")
        assert(btcUsdtTv == "BINGX:BTCUSDT.P", "Expected BINGX:BTCUSDT.P, got \(btcUsdtTv)")
        print("  ✅ [PASS] Normalisasi TradingView: 'BTCUSDT' -> '\(btcUsdtTv)'")

        let binanceStripTv = FuturesScoutMarketDataService.normalizeSymbolForTradingView("BINANCE:BTCUSDT")
        assert(binanceStripTv == "BINGX:BTCUSDT.P", "Expected BINGX:BTCUSDT.P, got \(binanceStripTv)")
        print("  ✅ [PASS] Normalisasi TradingView (Strip Binance Spot): 'BINANCE:BTCUSDT' -> '\(binanceStripTv)'")

        let bingxCanonicalTv = FuturesScoutMarketDataService.normalizeSymbolForTradingView("BINGX:BTCUSDT.P")
        assert(bingxCanonicalTv == "BINGX:BTCUSDT.P", "Expected BINGX:BTCUSDT.P, got \(bingxCanonicalTv)")
        print("  ✅ [PASS] Normalisasi TradingView (Idempotent): 'BINGX:BTCUSDT.P' -> '\(bingxCanonicalTv)'")

        // -------------------------------------------------------------
        // 3. Live Market Data & Anti-Repaint isClosed Verification
        // -------------------------------------------------------------
        print("\n[MENGUJI KONEKTIVITAS DATA PASAR REAL-TIME & ANTI-REPAINT BAR (BINGX QUOTE)]")
        do {
            let klines = try await FuturesScoutMarketDataService.shared.fetchKlines(symbol: "BTC-USDT", interval: "1h", limit: 10)
            assert(!klines.isEmpty, "Klines should not be empty")
            print("  ✅ [PASS] Berhasil mengambil \(klines.count) kandel H1 BTC-USDT")

            // Anti-Repaint Verification: The very last candle in the array is currently forming and MUST have isClosed == false
            if let last = klines.last {
                assert(last.isClosed == false, "Kandel terakhir yang sedang berjalan WAJIB berstatus isClosed: false")
                print("  ✅ [PASS] Anti-Repaint: Kandel berjalan terakhir terverifikasi isClosed = false (Close: $\(last.close))")
            }

            // All previous candles MUST have isClosed == true
            for (idx, k) in klines.dropLast().enumerated() {
                assert(k.isClosed == true, "Kandel historis #\(idx) WAJIB berstatus isClosed: true")
            }
            print("  ✅ [PASS] Anti-Repaint: Seluruh \(klines.count - 1) kandel historis terverifikasi isClosed = true")

        } catch {
            print("  ⚠️ [INFO] Network live fetch note: \(error.localizedDescription) (Mock assertions will cover deterministic suites)")
        }

        // -------------------------------------------------------------
        // 4. Canonical H1 Trend Regime Test (EMA 21, 34, 200 Single Source of Truth)
        // -------------------------------------------------------------
        print("\n[MENGUJI KANON REZIM H1 ENGINE (EMA 21/34/200)]")
        let engine = AstronacciDeterministicEngine.shared

        // Test 4a: Insufficient bars (< 200) -> Fail-Closed to .choppy
        var shortKlines: [AstronacciKline] = []
        for i in 0..<50 {
            shortKlines.append(AstronacciKline(open: 100.0, high: 105.0, low: 95.0, close: 100.0, volume: 10.0, timestamp: Int64(i * 3600), isClosed: true))
        }
        let choppyResult = engine.detectH1Regime(klinesH1: shortKlines)
        assert(choppyResult.regime == .choppy, "Expected .choppy when H1 < 200 bars")
        print("  ✅ [PASS] Fail-Closed H1 < 200 bars: Terdeteksi .choppy (0 points)")

        // Test 4b: 210 bars in strong Bullish sequence
        var bullishKlines: [AstronacciKline] = []
        var basePrice = 20000.0
        for i in 0..<210 {
            basePrice += 100.0
            bullishKlines.append(AstronacciKline(open: basePrice - 20, high: basePrice + 30, low: basePrice - 30, close: basePrice, volume: 100.0, timestamp: Int64(i * 3600), isClosed: true))
        }
        let bullishResult = engine.detectH1Regime(klinesH1: bullishKlines)
        assert(bullishResult.regime == .bullish, "Expected .bullish on uptrend sequence")
        assert(bullishResult.ema21 != nil && bullishResult.ema34 != nil && bullishResult.ema200 != nil, "Expected EMA values")
        print("  ✅ [PASS] Canonical H1 Regime: Terdeteksi .bullish (EMA21: $\(String(format: "%.1f", bullishResult.ema21!)) > EMA34 > EMA200)")

        // Test 4c: 210 bars in strong Bearish sequence
        var bearishKlines: [AstronacciKline] = []
        basePrice = 80000.0
        for i in 0..<210 {
            basePrice -= 100.0
            bearishKlines.append(AstronacciKline(open: basePrice + 20, high: basePrice + 30, low: basePrice - 30, close: basePrice, volume: 100.0, timestamp: Int64(i * 3600), isClosed: true))
        }
        let bearishResult = engine.detectH1Regime(klinesH1: bearishKlines)
        assert(bearishResult.regime == .bearish, "Expected .bearish on downtrend sequence")
        print("  ✅ [PASS] Canonical H1 Regime: Terdeteksi .bearish (EMA21: $\(String(format: "%.1f", bearishResult.ema21!)) < EMA34 < EMA200)")

        // -------------------------------------------------------------
        // 5. Fibonacci Time Window (Anti Off-by-One Specification Tests)
        // -------------------------------------------------------------
        print("\n[MENGUJI DIMENSI WAKTU FIBONACCI (ANTI OFF-BY-ONE CONTRACT)]")

        // Case 5a: Exact match at bar 8 (inWindow)
        // Anchor at index 20, currentClosedIndex at index 28 -> count = 8
        let win8 = FuturesScoutCoreAnalyst.evaluateFibonacciTimeWindow(anchorIndex: 20, currentClosedIndex: 28)
        assert(win8.state == .inWindow, "Expected .inWindow at count 8")
        assert(win8.currentBarCount == 8, "Expected count 8, got \(win8.currentBarCount)")
        assert(win8.currentTargetFib == 8, "Expected target 8")
        assert(win8.barsRemaining == 0, "Expected barsRemaining 0")
        print("  ✅ [PASS] Fib Time: Bar ke-8 pas berada di state .inWindow (0 bar tersisa)")

        // Case 5b: Approaching bar 13 (barsRemaining = 3)
        // Anchor at index 20, currentClosedIndex at index 30 -> count = 10 -> remaining = 13 - 10 = 3
        let win10 = FuturesScoutCoreAnalyst.evaluateFibonacciTimeWindow(anchorIndex: 20, currentClosedIndex: 30)
        assert(win10.state == .approaching, "Expected .approaching at count 10")
        assert(win10.currentBarCount == 10, "Expected count 10")
        assert(win10.currentTargetFib == 13, "Expected next target 13")
        assert(win10.barsRemaining == 3, "Expected 3 bars remaining, got \(win10.barsRemaining)")
        print("  ✅ [PASS] Fib Time: Bar ke-10 menuju bar 13 terhitung eksak 3 bar tersisa (.approaching)")

        // Case 5c: Exact match at bar 21 (inWindow)
        let win21 = FuturesScoutCoreAnalyst.evaluateFibonacciTimeWindow(anchorIndex: 10, currentClosedIndex: 31)
        assert(win21.state == .inWindow, "Expected .inWindow at count 21")
        assert(win21.currentTargetFib == 21, "Expected target 21")
        print("  ✅ [PASS] Fib Time: Bar ke-21 pas berada di state .inWindow")

        // Case 5d: Window Passed (> 34 bars)
        let win45 = FuturesScoutCoreAnalyst.evaluateFibonacciTimeWindow(anchorIndex: 10, currentClosedIndex: 55)
        assert(win45.state == .windowPassed, "Expected .windowPassed when count > 34")
        assert(win45.currentBarCount == 45, "Expected count 45")
        print("  ✅ [PASS] Fib Time: Bar ke-45 (>34) terdeteksi .windowPassed secara deterministik")

        // Case 5e: No Anchor / Nil
        let winNil = FuturesScoutCoreAnalyst.evaluateFibonacciTimeWindow(anchorIndex: nil, currentClosedIndex: 50)
        assert(winNil.state == .noAnchor, "Expected .noAnchor when nil")
        print("  ✅ [PASS] Fib Time: Nil anchor fail-closed ke .noAnchor")

        // -------------------------------------------------------------
        // 6. Market Session DST-Resilience Verification
        // -------------------------------------------------------------
        print("\n[MENGUJI KEKEBALAN DST MARKET SESSION (LONDON & NY TZDB)]")

        // Winter Date: 15 January 2026 at 14:00 UTC (London = 14:00 UTC, NY = 09:00 EST -> London Open, NY not yet 09:30)
        var winterComps = DateComponents()
        winterComps.year = 2026
        winterComps.month = 1
        winterComps.day = 15
        winterComps.hour = 14
        winterComps.minute = 0
        winterComps.timeZone = TimeZone(identifier: "UTC")
        let winterDate = Calendar(identifier: .gregorian).date(from: winterComps)!

        let winterSession = FuturesScoutCoreAnalyst.getCurrentMarketSession(date: winterDate)
        assert(winterSession == .london, "14:00 UTC in January should be London session (NY opens at 14:30 UTC / 09:30 EST), got \(winterSession)")
        print("  ✅ [PASS] DST Winter Test: 15 Jan 14:00 UTC -> Terdeteksi .london (Bebas Distorsi DST)")

        // Summer Date: 15 July 2026 at 14:00 UTC (London BST = 15:00, NY EDT = 10:00 -> London-NY Overlap!)
        var summerComps = DateComponents()
        summerComps.year = 2026
        summerComps.month = 7
        summerComps.day = 15
        summerComps.hour = 14
        summerComps.minute = 0
        summerComps.timeZone = TimeZone(identifier: "UTC")
        let summerDate = Calendar(identifier: .gregorian).date(from: summerComps)!

        let summerSession = FuturesScoutCoreAnalyst.getCurrentMarketSession(date: summerDate)
        assert(summerSession == .londonNYOverlap, "14:00 UTC in July should be London-NY overlap (London 15:00 BST, NY 10:00 EDT), got \(summerSession)")
        print("  ✅ [PASS] DST Summer Test: 15 Jul 14:00 UTC -> Terdeteksi .londonNYOverlap (Tzdb Resilient)")

        // -------------------------------------------------------------
        // 7. Single Source of Truth Stochastic Integration
        // -------------------------------------------------------------
        print("\n[MENGUJI STOCHASTIC OSCILLATOR SSOT (M5 & M15)]")

        // Construct 20 synthetic bars with oversold dip & rebound
        var stochKlines: [AstronacciKline] = []
        var p = 100.0
        for i in 0..<15 {
            p -= 2.0 // Downtrend
            stochKlines.append(AstronacciKline(open: p + 1, high: p + 1.5, low: p - 1, close: p, volume: 10, timestamp: Int64(i * 300), isClosed: true))
        }
        // Rebound
        for i in 15..<20 {
            p += 3.0
            stochKlines.append(AstronacciKline(open: p - 1, high: p + 2, low: p - 1, close: p + 1.5, volume: 20, timestamp: Int64(i * 300), isClosed: true))
        }

        let stochM5 = engine.calculateStochastic(kPeriod: 5, dPeriod: 3, slowing: 3, klines: stochKlines)
        assert(stochM5.k > 0 && stochM5.k <= 100, "Stochastic %K must be bounded [0, 100], got \(stochM5.k)")
        assert(stochM5.d > 0 && stochM5.d <= 100, "Stochastic %D must be bounded [0, 100], got \(stochM5.d)")
        print("  ✅ [PASS] Stochastic SSOT: %K: \(String(format: "%.1f", stochM5.k)), %D: \(String(format: "%.1f", stochM5.d)) terhitung dari engine langsung")

        // -------------------------------------------------------------
        // 8. End-to-End Pure Mathematical Core Analyst Test
        // -------------------------------------------------------------
        print("\n[MENGUJI PURE MATHEMATICAL CORE ANALYST (FUTURES_SCOUT_CORE_ANALYST)]")

        // Construct synthetic M15 bars with a clear dominant swing (low at bar 10, high at bar 35, pullback to bar 45)
        var m15Klines: [AstronacciKline] = []
        var m15Price = 60000.0
        for i in 0..<50 {
            if i < 10 {
                m15Price = 60000.0
            } else if i <= 35 {
                m15Price += 400.0 // Impulsive rise to ~70000
            } else {
                m15Price -= 250.0 // Pullback into Golden Pocket
            }
            m15Klines.append(AstronacciKline(
                open: m15Price - 50,
                high: m15Price + 80,
                low: m15Price - 80,
                close: m15Price,
                volume: 50.0,
                timestamp: Int64(i * 900),
                isClosed: true
            ))
        }

        // Construct synthetic M5 bars with a bullish pin bar at the end
        var m5Klines: [AstronacciKline] = []
        var m5Price = 65000.0
        for i in 0..<20 {
            m5Price += 10.0
            m5Klines.append(AstronacciKline(open: m5Price, high: m5Price + 20, low: m5Price - 20, close: m5Price + 10, volume: 10, timestamp: Int64(i * 300), isClosed: true))
        }
        // Add pin bar on bar 19
        m5Klines[18] = AstronacciKline(open: 65100, high: 65120, low: 64800, close: 65110, volume: 50, timestamp: 19 * 300, isClosed: true) // Long tail
        m5Klines[19] = AstronacciKline(open: 65110, high: 65150, low: 65100, close: 65140, volume: 10, timestamp: 20 * 300, isClosed: false) // Live candle

        let analysisResult = FuturesScoutCoreAnalyst.analyze(
            rawSymbol: "BTC",
            klinesH1: bullishKlines,
            klinesM15: m15Klines,
            klinesM5: m5Klines,
            referenceDate: summerDate,
            engine: engine
        )

        switch analysisResult {
        case .failure(let err):
            assertionFailure("Core Analyst should not fail with valid synthetic data: \(err)")
        case .success(let res):
            assert(res.symbol == "BTC/USDT", "Expected BTC/USDT")
            assert(res.regime == .bullish, "Expected bullish regime")
            assert(res.gpHigh > res.gpLow, "Expected valid GP range")
            assert(res.invalidationLevel < res.gpLow, "Expected invalidation level below Golden Pocket on Bullish")
            assert(res.targetExpansion1272 > res.swingHigh, "Expected TP1 above Swing High")
            assert(res.targetExpansion1618 > res.targetExpansion1272, "Expected TP2 above TP1")
            assert(res.marketSession == .londonNYOverlap, "Expected London-NY overlap")
            print("  ✅ [PASS] Pure Core Analyst: Analisis berhasil dieksekusi murni tanpa AppKit/UI/CUA!")
            print("  ✅ [PASS] Geometri Astronacci: GP $\(String(format: "%.1f", res.gpLow)) - $\(String(format: "%.1f", res.gpHigh)) • Invalidation: $\(String(format: "%.1f", res.invalidationLevel))")
            print("  ✅ [PASS] Proyeksi Target: TP1(1.272) $\(String(format: "%.1f", res.targetExpansion1272)) • TP2(1.618) $\(String(format: "%.1f", res.targetExpansion1618))")

            // -------------------------------------------------------------
            // 9. Clean Audio TTS & Presentation Contract Verification
            // -------------------------------------------------------------
            print("\n[MENGUJI KONTRAK PRESENTASI & KEBERSIHAN AUDIO TTS]")
            let (cardMarkdown, voiceNarrative) = FuturesScoutCoreAnalyst.renderPresentation(result: res)

            // Assertions for Voice Narrative:
            assert(!voiceNarrative.isEmpty, "Voice narrative must not be empty")
            assert(voiceNarrative.count <= 300, "Voice narrative must be <= 300 characters (Got: \(voiceNarrative.count))")

            // Strict Forbidden Markdown Characters in Speech:
            let forbiddenMarkdownChars: [Character] = ["#", "|", "*", "`", "[", "]", "{", "}", ">"]
            for ch in forbiddenMarkdownChars {
                assert(!voiceNarrative.contains(ch), "Voice narrative must NOT contain markdown character '\(ch)'!")
            }
            assert(!voiceNarrative.contains("---"), "Voice narrative must NOT contain divider lines '---'")
            assert(!voiceNarrative.contains("USDT"), "Voice narrative should be natural human speech without raw ticker tags")

            print("  ✅ [PASS] TTS Contract: Naskah suara terverifikasi 100% bebas markdown (\(voiceNarrative.count) karakter <= 300)")
            print("  🎙️ Naskah Suara: \"\(voiceNarrative)\"")

            // Assertions for Card Markdown:
            assert(cardMarkdown.contains("### 📊 Analisis Teknikal: BTC/USDT"), "Card must contain header")
            assert(cardMarkdown.contains("Golden Pocket"), "Card must contain Golden Pocket")
            assert(cardMarkdown.contains("Jendela Kandel Fibonacci"), "Card must contain Fibonacci Time Window")
            assert(cardMarkdown.contains("Catatan Edukasi"), "Card must contain mandatory 1-line disclaimer")
            print("  ✅ [PASS] Card Contract: Executive Briefing Card terverifikasi lengkap dengan level kunci & disclaimer")

            // -------------------------------------------------------------
            // 10. Pine Script Overlay Generator Verification (Option A Canon)
            // -------------------------------------------------------------
            print("\n[MENGUJI GENERATOR PINE SCRIPT OVERLAY V5 & TRADE PLAN BOX (OPSI A CANON)]")
            let pineOverlay = FuturesScoutCoreAnalyst.generatePineScriptOverlay(result: res)
            assert(pineOverlay.contains("//@version=5"), "Pine script must specify //@version=5")
            assert(pineOverlay.contains("indicator(\"Izanotchy Fibonacci Overlay\"") && pineOverlay.contains("overlay=true"), "Must be overlay indicator")
            assert(pineOverlay.contains("gp_high = "), "Must declare gp_high")
            assert(pineOverlay.contains("gp_low = "), "Must declare gp_low")
            assert(pineOverlay.contains("inv_level = "), "Must declare inv_level")
            assert(pineOverlay.contains("tp1_level = "), "Must declare tp1_level")
            assert(pineOverlay.contains("tp2_level = "), "Must declare tp2_level")
            assert(pineOverlay.contains("fill(gph, gpl,"), "Must fill Golden Pocket zone")

            // Option A: Visual Trade Plan Box Invariants
            assert(pineOverlay.contains("box.new("), "Must create visual risk/reward boxes")
            assert(pineOverlay.contains("label.new("), "Must create price and plan labels")
            assert(pineOverlay.contains("line.new("), "Must create precise entry limit line")
            assert(pineOverlay.contains("TRADE PLAN:"), "Must display TRADE PLAN badge")
            assert(pineOverlay.contains("[BUY LIMIT]") || pineOverlay.contains("[SELL LIMIT]"), "Must display directional limit tag")
            assert(pineOverlay.contains("[STOP LOSS]:"), "Must display STOP LOSS label")
            assert(pineOverlay.contains("[TAKE PROFIT 1]:"), "Must display TAKE PROFIT 1 label")
            assert(pineOverlay.contains("R:R 1:"), "Must calculate and display Risk:Reward ratio")

            // Verification of Pine Script v5 Variable Hoisting Invariant (Milestone 148)
            assert(!pineOverlay.contains("    var line"), "Pine Script v5 strictly forbids 'var' in local scope")
            assert(!pineOverlay.contains("    var label"), "Pine Script v5 strictly forbids 'var' in local scope")
            assert(pineOverlay.contains("var line time_line = na"), "time_line must be declared at global scope")
            assert(pineOverlay.contains("var label time_lbl = na"), "time_lbl must be declared at global scope")
            assert(pineOverlay.contains("var line qm_line = na"), "qm_line must be declared at global scope")
            assert(pineOverlay.contains("var label qm_lbl = na"), "qm_lbl must be declared at global scope")
            assert(pineOverlay.contains("table.cell(hud, 0, 0,"), "HUD Dashboard Table must be present")

            print("  ✅ [PASS] Pine Script v5 Generator & Trade Plan Box: Script terverifikasi akurat-harga lengkap dengan Kotak Reward (Hijau), Kotak Risk (Merah), Entry Line, Label R:R, dan Global Scope Variable Hoisting (Bebas 'var' Local Scope)")
            print("  📜 Sample Script Snippet:\n\(pineOverlay.prefix(300))...\n")

            // -------------------------------------------------------------
            // 11. Invalidation vs Structural Level Label Verification (Auditor Item)
            // -------------------------------------------------------------
            print("\n[MENGUJI DISTINGSI LEVEL INVALIDASI FIBONACCI VS STRUKTUR (AUDITOR GEMA)]")
            assert(cardMarkdown.contains("Level Invalidasi Fibonacci (78.6%)"), "Must label 78.6% as Fibonacci Invalidation")
            assert(cardMarkdown.contains("Batas Struktur Terakhir"), "Must display true structural swing level")
            print("  ✅ [PASS] Distingsi Level: 78.6% dilabeli 'Level Invalidasi Fibonacci' & struktur swing ditampilkan terpisah")

            // -------------------------------------------------------------
            // 12. Status Label & Trigger Alignment (Auditor Item)
            // -------------------------------------------------------------
            print("\n[MENGUJI LABEL STATUS & KONFIRMASI TRIGGER]")
            let setupLabel = FuturesScoutAnalysisResult.Status.setupDetected.rawValue
            assert(setupLabel.contains("Konfirmasi Reversal / Momentum"), "Status label must reflect Momentum/Stochastic OR Candlestick confirmation (Got: \(setupLabel))")
            print("  ✅ [PASS] Status Label: Terverifikasi '\(setupLabel)'")
        }

        // Test Choppy Presentation & Actionable Guidance (Reviewer Item)
        let choppyAnalysis = FuturesScoutCoreAnalyst.analyze(
            rawSymbol: "BTC",
            klinesH1: shortKlines,
            klinesM15: m15Klines,
            klinesM5: m5Klines,
            referenceDate: summerDate,
            engine: engine
        )
        if case .success(let choppyRes) = choppyAnalysis {
            assert(choppyRes.status == .standAsideChoppy, "Expected .standAsideChoppy")
            let (choppyCard, _) = FuturesScoutCoreAnalyst.renderPresentation(result: choppyRes)
            assert(choppyCard.contains("Kriteria Actionable"), "Choppy card must contain Actionable Criteria")
            assert(choppyCard.contains("**Target Proyeksi Ekspansi**: —"), "Choppy card must not contain false targets")
            assert(choppyCard.contains("**Overlay Chart**: —"), "Choppy card must state overlay not drawn")
            print("  ✅ [PASS] Actionable Choppy Guidance: Terverifikasi panduan kriteria actionable hadir pada status STAND ASIDE")
        }

        // -------------------------------------------------------------
        // 13. Fail-Closed resolvePoint Boundary Verification (Pillar 2 Safety Gate)
        // -------------------------------------------------------------
        print("\n[MENGUJI FAIL-CLOSED RESOLVEPOINT BOUNDARY (P2 SAFETY GATE)]")
        // Case 13a: nil windowBounds -> MUST return nil (Zero click fallback to NSScreen)
        let nilResolved = TradingViewInputSupport.resolvePoint(CGPoint(x: 500, y: 500), windowBounds: nil)
        assert(nilResolved == nil, "Fail-Closed Invariant: Nil windowBounds MUST return nil to prevent blind desktop clicks")
        print("  ✅ [PASS] Fail-Closed: Nil bounds mengembalikan nil (Nol fallback ke NSScreen/aplikasi lain)")

        // Case 13b: Point out of bounds -> MUST return nil
        let testBounds = CGRect(x: 100, y: 100, width: 1000, height: 700)
        let oobResolved = TradingViewInputSupport.resolvePoint(CGPoint(x: 2500, y: 2500), windowBounds: testBounds)
        assert(oobResolved == nil, "Out of bounds point must return nil")
        print("  ✅ [PASS] Fail-Closed: Koordinat di luar batas window ditolak (nil)")

        // Case 13c: Normalized point (0.5, 0.5) inside bounds -> physical center (600, 450)
        let normCenter = TradingViewInputSupport.resolvePoint(CGPoint(x: 0.5, y: 0.5), windowBounds: testBounds)
        assert(normCenter != nil, "Valid normalized point must resolve")
        assert(normCenter!.x == 600 && normCenter!.y == 450, "Expected center (600, 450), got \(normCenter!)")
        print("  ✅ [PASS] Safe Coordinate: Normalisasi (0.5, 0.5) terpetakan presisi ke \(normCenter!)")

        // Case 13d: Physical point clamped within safe canvas margins [minX+20, maxX-20, minY+45, maxY-35]
        let nearEdge = TradingViewInputSupport.resolvePoint(CGPoint(x: 105, y: 105), windowBounds: testBounds)
        assert(nearEdge != nil, "Near-edge point must resolve")
        assert(nearEdge!.x == 120.0, "Expected clamped minX 120.0, got \(nearEdge!.x)")
        assert(nearEdge!.y == 145.0, "Expected clamped minY 145.0, got \(nearEdge!.y)")
        print("  ✅ [PASS] Canvas Clamping: Koordinat tepi ter-clamp aman di margin kanvas TradingView (\(nearEdge!))")

        // -------------------------------------------------------------
        // 14. Keystroke Security Allowlist Verification
        // -------------------------------------------------------------
        print("\n[MENGUJI ALLOWLIST KEYSTROKE & KEAMANAN ORDER]")
        // Prohibit dangerous order hotkeys: Shift+B, Shift+S, Alt+B, Alt+S
        assert(!TradingViewInputSupport.isAllowedKey(11, flags: [.maskShift]), "Shift+B must be blocked")
        assert(!TradingViewInputSupport.isAllowedKey(1, flags: [.maskShift]), "Shift+S must be blocked")
        assert(!TradingViewInputSupport.isAllowedKey(11, flags: [.maskAlternate]), "Alt+B must be blocked")
        assert(!TradingViewInputSupport.isAllowedKey(1, flags: [.maskAlternate]), "Alt+S must be blocked")
        // Prohibit Cmd+W
        assert(!TradingViewInputSupport.isAllowedKey(13, flags: [.maskCommand]), "Cmd+W must be blocked")
        // Option+E must be blocked (deprecated due to macOS dead key acute accent trap)
        assert(!TradingViewInputSupport.isAllowedKey(14, flags: [.maskAlternate]), "Option+E must be blocked due to dead key trap on macOS")
        // Allow Auto-scale Option+R, HLine Option+H, HRay Option+J
        assert(TradingViewInputSupport.isAllowedKey(15, flags: [.maskAlternate]), "Option+R must be allowed")
        assert(TradingViewInputSupport.isAllowedKey(4, flags: [.maskAlternate]), "Option+H must be allowed")
        assert(TradingViewInputSupport.isAllowedKey(38, flags: [.maskAlternate]), "Option+J must be allowed")
        print("  ✅ [PASS] Keystroke Security: Order hotkeys & Cmd+W terblokir 100%; hotkey navigasi diizinkan")

        // -------------------------------------------------------------
        // 15. Keycode 0...127 Regression Sweep & Scoped Cmd+C Test (Agent 1 & 2 Spec)
        // -------------------------------------------------------------
        print("\n[MENGUJI REGRESSION SWEEP KEYCODE 0...127 & SCOPED CMD+C (AGENT 1 & 2)]")
        // Step A: Verify Cmd+C is rejected when isPineScriptBackupActive == false
        TradingViewInputSupport.isPineScriptBackupActive = false
        assert(!TradingViewInputSupport.isAllowedKey(8, flags: [.maskCommand]), "Cmd+C MUST be blocked globally when backup inactive")
        // Step B: Verify Cmd+C is accepted when isPineScriptBackupActive == true
        TradingViewInputSupport.isPineScriptBackupActive = true
        assert(TradingViewInputSupport.isAllowedKey(8, flags: [.maskCommand]), "Cmd+C MUST be allowed when isPineScriptBackupActive == true")
        TradingViewInputSupport.isPineScriptBackupActive = false

        // Step C: Full 0...127 Sweep across flag combinations: must NEVER crash & must be fail-closed for non-allowlisted keys
        let flagCombos: [CGEventFlags] = [
            [],
            [.maskCommand],
            [.maskAlternate],
            [.maskShift],
            [.maskControl],
            [.maskCommand, .maskAlternate],
            [.maskCommand, .maskShift]
        ]

        var testedKeyCombinations = 0
        for code in 0...127 {
            let keyCode = CGKeyCode(code)
            for flags in flagCombos {
                // Call isAllowedKey - must never crash with fatalError or assertion failure
                let allowed = TradingViewInputSupport.isAllowedKey(keyCode, flags: flags)
                testedKeyCombinations += 1

                // If code is an order hotkey with modifier, must ALWAYS be false
                if (keyCode == 11 || keyCode == 1) && (flags.contains(.maskShift) || flags.contains(.maskAlternate) || flags.contains(.maskControl)) {
                    assert(!allowed, "Order hotkey \(keyCode) with flags \(flags.rawValue) must be blocked")
                }

                // If code is Cmd+W (13 with Cmd), must ALWAYS be false
                if keyCode == 13 && flags.contains(.maskCommand) {
                    assert(!allowed, "Cmd+W must be blocked")
                }
            }
        }
        print("  ✅ [PASS] Keycode Sweep: \(testedKeyCombinations) kombinasi keycode (0...127) teruji bebas crash 100% (Zero landmine)")
        print("  ✅ [PASS] Scoped Cmd+C: Ditolak secara global (false), diizinkan eksklusif saat isPineScriptBackupActive = true")

        // -------------------------------------------------------------
        // 16. Dynamic Price Formatting Across Price Tiers (Sub-Dollar Precision)
        // -------------------------------------------------------------
        print("\n[MENGUJI PRESISI DINAMIS FORMAT HARGA MULTI-TIER (BTC, SOL, ASTER, PEPE)]")
        let btcFormatted = FuturesScoutCoreAnalyst.formatPrice(84012.345)
        assert(btcFormatted == "84012.3", "Expected 84012.3, got \(btcFormatted)")

        let solFormatted = FuturesScoutCoreAnalyst.formatPrice(145.248)
        assert(solFormatted == "145.25", "Expected 145.25, got \(solFormatted)")

        let asterFormatted = FuturesScoutCoreAnalyst.formatPrice(0.74152)
        assert(asterFormatted == "0.7415", "Expected 0.7415, got \(asterFormatted)")

        let pepeFormatted = FuturesScoutCoreAnalyst.formatPrice(0.00001854)
        assert(pepeFormatted == "0.00001854", "Expected 0.00001854, got \(pepeFormatted)")
        print("  ✅ [PASS] Presisi Multi-Tier: BTC (1 desimal), SOL (2 desimal), ASTER (4 desimal), PEPE (8 desimal) terverifikasi presisi")

        // -------------------------------------------------------------
        // 17. Sub-Dollar Coin Mathematical & Presentation Integrity (ASTER/USDT)
        // -------------------------------------------------------------
        print("\n[MENGUJI INTEGRITAS MATEMATIKA KOIN SUB-DOLLAR (ASTER/USDT $0.74)]")
        // Construct synthetic ASTER klines with sub-dollar range (High $0.75, Low $0.73, Range $0.02)
        var asterH1: [AstronacciKline] = []
        var asterBase = 0.50
        for i in 0..<210 {
            asterBase += 0.001
            asterH1.append(AstronacciKline(open: asterBase, high: asterBase + 0.002, low: asterBase - 0.001, close: asterBase + 0.001, volume: 1000.0, timestamp: Int64(i * 3600), isClosed: true))
        }

        var asterM15: [AstronacciKline] = []
        for i in 0..<50 {
            let p = 0.73 + Double(i % 10) * 0.002
            asterM15.append(AstronacciKline(open: p, high: min(0.75, p + 0.003), low: max(0.73, p - 0.002), close: p, volume: 500.0, timestamp: Int64(i * 900), isClosed: true))
        }

        var asterM5: [AstronacciKline] = []
        for i in 0..<49 {
            let p = 0.738 + Double(i % 5) * 0.001
            asterM5.append(AstronacciKline(open: p, high: p + 0.001, low: p - 0.001, close: p, volume: 100.0, timestamp: Int64(i * 300), isClosed: true))
        }
        // Last bar forming (isClosed: false)
        asterM5.append(AstronacciKline(open: 0.7410, high: 0.7420, low: 0.7405, close: 0.7415, volume: 50.0, timestamp: 49 * 300, isClosed: false))

        let asterResult = FuturesScoutCoreAnalyst.analyze(
            rawSymbol: "ASTER",
            klinesH1: asterH1,
            klinesM15: asterM15,
            klinesM5: asterM5,
            engine: engine
        )

        switch asterResult {
        case .success(let res):
            assert(res.swingRange < 0.1, "Sub-dollar swing range must NOT be clamped to 1.0! Got \(res.swingRange)")
            assert(res.gpLow > 0.60 && res.gpLow < 0.80, "Golden Pocket low must be in realistic range! Got \(res.gpLow)")
            assert(res.invalidationLevel > 0.50, "Invalidation level must be strictly positive! Got \(res.invalidationLevel)")

            let (card, voice) = FuturesScoutCoreAnalyst.renderPresentation(result: res)
            assert(!card.contains("$-0.0"), "Card must never contain negative zero ($-0.0)! Got:\n\(card)")
            assert(!card.contains("lebar $1.0"), "Card must not report fake $1.0 range! Got:\n\(card)")
            assert(!voice.contains(" 0 dolar"), "Voice narrative must not say '0 dolar' for sub-dollar coins! Got: \(voice)")

            let pineScript = FuturesScoutCoreAnalyst.generatePineScriptOverlay(result: res)
            assert(pineScript.contains("#.####"), "Sub-dollar Pine Script overlay must use #.#### precision for labels! Got:\n\(pineScript)")
            print("  ✅ [PASS] Sub-Dollar Token Math: Range \(res.swingRange) terukur alami (<0.1), GP $\(res.gpLow) - $\(res.gpHigh), SL $\(res.invalidationLevel) > 0")
            print("  ✅ [PASS] Sub-Dollar Presentation: Bebas distorsi $-0.0, label Pine Script menggunakan presisi #.####")
        case .failure(let err):
            fatalError("ASTER analysis failed: \(err)")
        }

        // -------------------------------------------------------------
        // 14. High-Impact News Buffer Presentation & Moon Ingress Caveat Verification
        // -------------------------------------------------------------
        print("\n[MENGUJI PERILAKU PRESENTASI BUFFER BERITA & CAVEAT INGRESS BULAN (SIMULASI RIIL)]")
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        let cpiDate = isoFormatter.date(from: "2026-04-10T12:00:00Z")! // 30 min before CPI release (12:30 UTC / 08:30 EDT)

        let cpiAnalysis = FuturesScoutCoreAnalyst.analyze(
            rawSymbol: "BTC",
            klinesH1: bullishKlines,
            klinesM15: m15Klines,
            klinesM5: m5Klines,
            referenceDate: cpiDate,
            engine: engine
        )
        switch cpiAnalysis {
        case .success(let res):
            assert(res.newsBuffer.isInsideBuffer == true, "Expected news buffer active for 30m before CPI")
            assert(res.newsBuffer.activeEvent?.name == "US CPI Inflation", "Expected US CPI Inflation active event")

            let (card, voice) = FuturesScoutCoreAnalyst.renderPresentation(result: res)

            // Verify prominent red warning banner
            assert(card.contains("PERINGATAN BUFFER BERITA BESAR (SOP ASTRONACCI)"), "Card must display high-impact news buffer banner")
            assert(card.contains("US CPI Inflation"), "Card banner must name US CPI Inflation")
            assert(card.contains("STAND ASIDE"), "Card banner must advise STAND ASIDE")

            // Verify voice warning contract (<300 chars, NO markdown)
            assert(voice.contains("Perhatian, rilis berita ekonomi besar US CPI Inflation"), "Voice must announce CPI warning")
            assert(voice.contains("Stand Aside"), "Voice must advise Stand Aside")
            assert(voice.count <= 300, "Voice must be <= 300 characters, got \(voice.count)")
            let speechForbidden: [Character] = ["#", "|", "*", "`", "[", "]", "{", "}", ">"]
            for ch in speechForbidden {
                assert(!voice.contains(ch), "Voice must NOT contain markdown character '\(ch)'!")
            }
            print("  ✅ [PASS] Behavioral Proof: Banner merah buffer berita & naskah suara Stand Aside teruji")

            // Verify Moon ingress timing caveat if Moon ingress is active
            if !res.planetaryAspects.activeIngress.isEmpty && res.planetaryAspects.activeIngress.contains(where: { $0.body == .moon }) {
                assert(card.contains("Perkiraan timing ±2 jam untuk Bulan"), "Card must display Moon timing precision caveat")
                print("  ✅ [PASS] Moon Ingress Caveat: Klausul 'Perkiraan timing ±2 jam' terverifikasi di kartu")
            }
        case .failure(let err):
            fatalError("CPI analysis failed: \(err)")
        }

        print("\n=================================================================")
        print("🏁 HASIL AKHIR: SELURUH UJI FASE 1 & FASE 2 LOLOS 100%!")
        print("=================================================================")
    }
}
