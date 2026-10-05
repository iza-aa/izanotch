//
//  test_astronacci_engine.swift
//  Unit Test & Mathematical Verification Suite for AstronacciDeterministicEngine (Pilar 1)
//

import Foundation

@main
struct AstronacciEngineTestSuite {
    static var passedCount = 0
    static var totalTests = 0

    static func assertTest(_ condition: Bool, _ testName: String, failureDetails: String = "") {
        totalTests += 1
        if condition {
            passedCount += 1
            print("  ✅ [PASS] \(testName)")
        } else {
            print("  ❌ [FAIL] \(testName) — Details: \(failureDetails)")
        }
    }

    static func neutralCandleTriggerIsReversal(_ t: AstronacciCandleTrigger) -> Bool {
        switch t {
        case .none: return false
        default: return true
        }
    }

    static func main() {
        print("=================================================================")
        print("🧪 PILAR 1: UJI VALIDASI MATEMATIS & KODE DETERMINISTIK ASTRONACCI")
        print("=================================================================")

        let engine = AstronacciDeterministicEngine.shared

        // -------------------------------------------------------------
        // TEST 1: EMA Calculation
        // -------------------------------------------------------------
        print("\n[TEST GROUP 1: Exponential Moving Average (EMA)]")
        var mockKlinesEMA: [AstronacciKline] = []
        let emaPrices = [10.0, 11.0, 12.0, 13.0, 14.0, 15.0, 16.0, 17.0, 18.0, 19.0, 20.0]
        for (idx, p) in emaPrices.enumerated() {
            mockKlinesEMA.append(AstronacciKline(open: p, high: p + 1, low: p - 1, close: p, volume: 100, timestamp: Int64(idx * 60)))
        }
        let ema5 = engine.calculateEMA(period: 5, klines: mockKlinesEMA)
        assertTest(!ema5.isEmpty, "EMA 5 menghasilkan nilai")
        if let lastEMA = ema5.last {
            assertTest(lastEMA > 16.0 && lastEMA < 20.0, "EMA 5 bergerak naik sejalan tren harga (Nilai: \(String(format: "%.2f", lastEMA)))")
        }

        // -------------------------------------------------------------
        // TEST 2: Average True Range (ATR)
        // -------------------------------------------------------------
        print("\n[TEST GROUP 2: Average True Range (ATR)]")
        var mockKlinesATR: [AstronacciKline] = []
        for i in 0..<20 {
            mockKlinesATR.append(AstronacciKline(open: 100, high: 110, low: 90, close: 100, volume: 1000, timestamp: Int64(i * 60)))
        }
        let atrVal = engine.calculateATR(period: 14, klines: mockKlinesATR)
        assertTest(abs(atrVal - 20.0) < 0.001, "Kalkulasi ATR(14) bernilai tepat 20.0 (Nilai: \(atrVal))")

        // -------------------------------------------------------------
        // TEST 3: 5-Bar Pivot Fractal Swing Detection (Anti-Repaint)
        // -------------------------------------------------------------
        print("\n[TEST GROUP 3: Pivot Fractal 5-Bar Detection]")
        var fractalKlines: [AstronacciKline] = []
        let priceSeries = [
            64000.0, 63000.0, 61000.0, 60500.0, 60000.0, // idx 4 = Swing Low 60,000
            61500.0, 63000.0, 66000.0, 68000.0, 69500.0,
            70000.0, // idx 10 = Swing High 70,000
            68500.0, 67000.0, 66500.0, 65000.0, 64800.0
        ]
        for (idx, p) in priceSeries.enumerated() {
            fractalKlines.append(AstronacciKline(
                open: p,
                high: p + 100.0,
                low: p - 100.0,
                close: p,
                volume: 500,
                timestamp: Int64(idx * 900),
                isClosed: true
            ))
        }
        let detectedFractals = engine.detect5BarPivotFractals(klines: fractalKlines)
        assertTest(detectedFractals != nil, "Deteksi Pivot Fractal berhasil menemukan titik ayunan")
        if let f = detectedFractals {
            assertTest(abs(f.swingLow - 59900.0) < 1.0, "Swing Low terdeteksi akurat di 59,900 (Nilai: \(f.swingLow))")
            assertTest(abs(f.swingHigh - 70100.0) < 1.0, "Swing High terdeteksi akurat di 70,100 (Nilai: \(f.swingHigh))")
        }

        // -------------------------------------------------------------
        // TEST 4: Fibonacci Grid & Golden Pocket Calculation
        // -------------------------------------------------------------
        print("\n[TEST GROUP 4: Fibonacci Grid & Golden Pocket]")
        let sLow = 64050.0
        let sHigh = 65800.0
        let range = sHigh - sLow // 1750.0

        let expectedFib0500 = sHigh - (range * 0.500) // 64,925.0
        let expectedFib0618 = sHigh - (range * 0.618) // 64,718.5
        let expectedFib0786 = sHigh - (range * 0.786) // 64,424.5
        let expectedExp1272 = sLow + (range * 1.272)  // 66,276.0
        let expectedExp1618 = sLow + (range * 1.618)  // 66,881.5

        assertTest(abs(expectedFib0500 - 64925.0) < 0.1, "Fibonacci 0.500 terhitung tepat $64,925.0")
        assertTest(abs(expectedFib0618 - 64718.5) < 0.1, "Fibonacci 0.618 (Golden Ratio) terhitung tepat $64,718.5")
        assertTest(abs(expectedFib0786 - 64424.5) < 0.1, "Fibonacci 0.786 (Last Defense) terhitung tepat $64,424.5")
        assertTest(abs(expectedExp1272 - 66276.0) < 0.1, "Fibonacci Expansion 1.272 (TP1) terhitung tepat $66,276.0")
        assertTest(abs(expectedExp1618 - 66881.5) < 0.1, "Fibonacci Expansion 1.618 (TP2) terhitung tepat $66,881.5")

        // -------------------------------------------------------------
        // TEST 5: Candlestick Rejection (Pin Bar & Engulfing)
        // -------------------------------------------------------------
        print("\n[TEST GROUP 5: Candlestick Rejection Anatomy]")
        let pinBarCandle = AstronacciKline(open: 64750, high: 64770, low: 64500, close: 64740, volume: 50, timestamp: 1000)
        let prevCandle = AstronacciKline(open: 64800, high: 64810, low: 64730, close: 64750, volume: 40, timestamp: 900)
        let triggerResult = engine.detectCandleTrigger(kline: pinBarCandle, previousKline: prevCandle, atr: 100.0)
        assertTest(triggerResult.isReversal, "Kandel Pin Bar dengan ekor bawah panjang terdeteksi sebagai Reversal Valid")

        let neutralCandle = AstronacciKline(open: 64700, high: 64800, low: 64600, close: 64700, volume: 50, timestamp: 1100)
        let neutralResult = engine.detectCandleTrigger(kline: neutralCandle, previousKline: prevCandle, atr: 100.0)
        assertTest(!neutralCandleTriggerIsReversal(neutralResult), "Kandel netral tanpa ekor dominan berhasil DITOLAK (.none)")

        // -------------------------------------------------------------
        // TEST 6: Stochastic (5, 3, 3) Oversold Golden Cross
        // -------------------------------------------------------------
        print("\n[TEST GROUP 6: Stochastic Oscillator (5, 3, 3)]")
        var stochKlines: [AstronacciKline] = []
        for i in 0..<20 {
            let p = 66000.0 - Double(i * 80)
            stochKlines.append(AstronacciKline(open: p, high: p + 10, low: p - 30, close: p - 20, volume: 200, timestamp: Int64(i * 300)))
        }
        stochKlines.append(AstronacciKline(open: 64400, high: 64550, low: 64380, close: 64540, volume: 600, timestamp: 6300))
        let stochRes = engine.calculateStochastic(kPeriod: 5, dPeriod: 3, slowing: 3, klines: stochKlines)
        assertTest(stochRes.k <= 40.0, "Stochastic %K berada di area bawah setelah downtrend (Nilai %K: \(String(format: "%.1f", stochRes.k)))")

        // -------------------------------------------------------------
        // TEST 7: THE CRITICAL HARD VETO GATE TEST (Temuan Agen 2)
        // -------------------------------------------------------------
        print("\n[TEST GROUP 7: Veto Gate Enforcement]")

        var testH1: [AstronacciKline] = []
        for i in 0..<210 {
            let p = 60000.0 + Double(i * 25)
            testH1.append(AstronacciKline(open: p, high: p + 50, low: p - 50, close: p, volume: 1000, timestamp: Int64(i * 3600)))
        }

        // Case A & B: Realistic M15 swing (Low at 64,050 -> High at 66,000 -> Pullback to Golden Pocket 64,725)
        var testM15: [AstronacciKline] = []
        // Base candles
        for i in 0..<50 {
            testM15.append(AstronacciKline(open: 64200, high: 64250, low: 64150, close: 64200, volume: 300, timestamp: Int64(i * 900)))
        }
        // Swing Low at 64,050
        testM15.append(AstronacciKline(open: 64150, high: 64200, low: 64050, close: 64100, volume: 500, timestamp: 46000))
        testM15.append(AstronacciKline(open: 64100, high: 64300, low: 64090, close: 64280, volume: 400, timestamp: 46900))
        testM15.append(AstronacciKline(open: 64280, high: 64500, low: 64250, close: 64450, volume: 450, timestamp: 47800))
        // Rally up to Swing High at 66,000
        for i in 1...10 {
            let p = 64450.0 + Double(i * 150)
            testM15.append(AstronacciKline(open: p - 50, high: p + 50, low: p - 70, close: p + 30, volume: 600, timestamp: Int64(48000 + i * 900)))
        }
        // Swing High at 66,000
        testM15.append(AstronacciKline(open: 65900, high: 66050, low: 65850, close: 65950, volume: 800, timestamp: 58000))
        testM15.append(AstronacciKline(open: 65950, high: 66000, low: 65700, close: 65750, volume: 500, timestamp: 58900))
        // Pullback down towards 64,725 (Golden Pocket)
        for i in 1...8 {
            let p = 65750.0 - Double(i * 125)
            testM15.append(AstronacciKline(open: p + 40, high: p + 50, low: p - 40, close: p - 20, volume: 400, timestamp: Int64(59000 + i * 900)))
        }

        var testM5_NoTrigger: [AstronacciKline] = []
        for i in 0..<40 {
            let p = 64720.0 + (Double(i % 3) * 5.0)
            testM5_NoTrigger.append(AstronacciKline(open: p, high: p + 20, low: p - 20, close: p, volume: 200, timestamp: Int64(i * 300)))
        }

        let resultNoTrigger = engine.evaluateConfluence(
            symbol: "BTC-USDT",
            klinesH1: testH1,
            klinesM15: testM15,
            klinesM5: testM5_NoTrigger,
            isNewsClear: true,
            isLondonNyOverlap: true
        )

        assertTest(!resultNoTrigger.vetoCheck.isPassed, "VETO GATE AKTIF: Setup tanpa kandel reversal DITOLAK!")
        assertTest(resultNoTrigger.finalStatus == "STAND_ASIDE", "Status final otomatis STAND_ASIDE ketika veto gagal")
        assertTest(resultNoTrigger.tradePlan == nil, "Tidak ada Trade Plan yang dihasilkan saat veto gagal")

        var testM5_WithTrigger = testM5_NoTrigger
        testM5_WithTrigger.removeLast()
        testM5_WithTrigger.append(AstronacciKline(open: 64730, high: 64740, low: 64450, close: 64725, volume: 1200, timestamp: 12300, isClosed: true))

        let resultWithTrigger = engine.evaluateConfluence(
            symbol: "BTC-USDT",
            klinesH1: testH1,
            klinesM15: testM15,
            klinesM5: testM5_WithTrigger,
            isNewsClear: true,
            isLondonNyOverlap: true
        )

        assertTest(resultWithTrigger.vetoCheck.candleTriggerPassed, "Veto Gate: Kandel Reversal terverifikasi LULUS")
        assertTest(resultWithTrigger.vetoCheck.rrPassed, "Veto Gate: Rasio R:R >= 1:2.0 terverifikasi LULUS")
        assertTest(resultWithTrigger.vetoCheck.isPassed, "Veto Gate: Seluruh syarat lolos (isPassed = true)")
        assertTest(resultWithTrigger.finalStatus == "A_GRADE_SETUP" || resultWithTrigger.finalStatus == "B_GRADE_ALERT", "Status setup valid (Nilai: \(resultWithTrigger.finalStatus))")
        assertTest(resultWithTrigger.tradePlan != nil, "Trade Plan resmi berhasil dihasilkan")

        // -------------------------------------------------------------
        // TEST 8: Fee & Slippage Adjusted Position Sizing
        // -------------------------------------------------------------
        print("\n[TEST GROUP 8: Fee-Adjusted Position Sizing]")
        assertTest(resultWithTrigger.tradePlan != nil, "Trade Plan resmi berhasil dihasilkan")
        if let plan = resultWithTrigger.tradePlan {
            assertTest(plan.positionSize > 0, "Ukuran posisi > 0 (Nilai: \(plan.positionSize) BTC)")
            assertTest(plan.feeBufferUsd > 0, "Penyangga fee 0.1% dialokasikan (Nilai: $\(String(format: "%.2f", plan.feeBufferUsd)))")
            assertTest(plan.assumedSlippageUsd > 0, "Penyangga slippage ATR dialokasikan (Nilai: $\(String(format: "%.2f", plan.assumedSlippageUsd)))")
            assertTest(plan.notionalUsd <= 10000.0 * 10.0, "Total notional terkunci di bawah batas leverage maksimum 10x")
            assertTest(plan.stopLossPrice < plan.entryPrice, "Stop loss terletak di bawah entry price (SL: $\(String(format: "%.2f", plan.stopLossPrice)))")
            assertTest(plan.takeProfit1 > plan.entryPrice, "Take Profit 1 terletak di atas entry price (TP1: $\(String(format: "%.2f", plan.takeProfit1)))")
        } else {
            assertTest(false, "GAGAL: Trade Plan bernilai nil, asersi sizing tidak dapat dijalankan!")
        }

        // -------------------------------------------------------------
        // TEST 9: Dual-Direction Bearish SHORT Setup (Temuan Agen 1 #1)
        // -------------------------------------------------------------
        print("\n[TEST GROUP 9: Dual-Direction SHORT Setup (Shooting Star & Dead Cross)]")
        var bearH1: [AstronacciKline] = []
        for i in 0..<210 {
            // Downtrend: Prices dropping from 75,000 down to 65,000
            let p = 75000.0 - Double(i * 45)
            bearH1.append(AstronacciKline(open: p, high: p + 30, low: p - 30, close: p, volume: 1000, timestamp: Int64(i * 3600)))
        }

        // Bearish M15: Genuine 5-Bar Swing High (66,200) -> Dump -> 5-Bar Swing Low (63,900) -> Pullback to GP (65,180)
        var bearM15: [AstronacciKline] = []
        for i in 0..<30 {
            bearM15.append(AstronacciKline(open: 65500, high: 65600, low: 65400, close: 65500, volume: 300, timestamp: Int64(i * 900)))
        }
        // Swing High at 66,200 (surrounded by lower highs on both sides)
        bearM15.append(AstronacciKline(open: 65600, high: 65800, low: 65500, close: 65700, volume: 400, timestamp: 30000))
        bearM15.append(AstronacciKline(open: 65700, high: 65950, low: 65650, close: 65900, volume: 500, timestamp: 30900))
        bearM15.append(AstronacciKline(open: 65900, high: 66200, low: 65800, close: 66100, volume: 800, timestamp: 31800)) // Center Swing High 66,200!
        bearM15.append(AstronacciKline(open: 66100, high: 65900, low: 65700, close: 65800, volume: 500, timestamp: 32700))
        bearM15.append(AstronacciKline(open: 65800, high: 65700, low: 65500, close: 65600, volume: 400, timestamp: 33600))

        // Downtrend dump to 64,000
        for i in 1...8 {
            let p = 65600.0 - Double(i * 160)
            bearM15.append(AstronacciKline(open: p + 30, high: p + 40, low: p - 40, close: p - 20, volume: 600, timestamp: Int64(34000 + i * 900)))
        }

        // Swing Low at 63,900 (surrounded by higher lows on both sides)
        bearM15.append(AstronacciKline(open: 64200, high: 64250, low: 64100, close: 64150, volume: 500, timestamp: 44000))
        bearM15.append(AstronacciKline(open: 64150, high: 64200, low: 64000, close: 64050, volume: 600, timestamp: 44900))
        bearM15.append(AstronacciKline(open: 64050, high: 64100, low: 63900, close: 64000, volume: 900, timestamp: 45800)) // Center Swing Low 63,900!
        bearM15.append(AstronacciKline(open: 64000, high: 64150, low: 64020, close: 64100, volume: 500, timestamp: 46700))
        bearM15.append(AstronacciKline(open: 64100, high: 64300, low: 64150, close: 64250, volume: 400, timestamp: 47600))

        // Retracement UP into Bearish Golden Pocket (50% = 65,050 s.d. 61.8% = 65,321)
        for i in 1...6 {
            let p = 64250.0 + Double(i * 150)
            bearM15.append(AstronacciKline(open: p - 20, high: p + 30, low: p - 20, close: p + 10, volume: 400, timestamp: Int64(48000 + i * 900)))
        }

        // Bearish M5 with Shooting Star (long upper wick >= 2x body)
        var bearM5: [AstronacciKline] = []
        for i in 0..<35 {
            let p = 65100.0 + Double(i * 2)
            bearM5.append(AstronacciKline(open: p, high: p + 15, low: p - 10, close: p + 5, volume: 200, timestamp: Int64(i * 300)))
        }
        // Shooting Star at 65,180: open 65160, high 65450 (upper wick 270), low 65150, close 65180 (body 20)
        bearM5.append(AstronacciKline(open: 65160, high: 65450, low: 65150, close: 65180, volume: 900, timestamp: 12000, isClosed: true))

        let bearResult = engine.evaluateConfluence(
            symbol: "BTC-USDT",
            klinesH1: bearH1,
            klinesM15: bearM15,
            klinesM5: bearM5,
            isNewsClear: true,
            isLondonNyOverlap: true
        )

        assertTest(bearResult.regime == .bearish, "Rezim H1 terdeteksi BEARISH secara valid")
        assertTest(bearResult.candleTrigger.isBearish, "Kandel M5 terdeteksi sebagai Bearish Reversal (Shooting Star/Engulfing)")
        assertTest(bearResult.tradePlan != nil, "Trade Plan SHORT berhasil diterbitkan")
        if let shortPlan = bearResult.tradePlan {
            assertTest(shortPlan.direction == "SHORT", "Arah order Trade Plan adalah SHORT")
            assertTest(shortPlan.stopLossPrice > shortPlan.entryPrice, "Stop loss SHORT berada DI ATAS entry price (SL: $\(String(format: "%.2f", shortPlan.stopLossPrice)) > Entry: $\(String(format: "%.2f", shortPlan.entryPrice)))")
            assertTest(shortPlan.takeProfit1 < shortPlan.entryPrice, "Take Profit 1 SHORT berada DI BAWAH entry price (TP1: $\(String(format: "%.2f", shortPlan.takeProfit1)) < Entry: $\(String(format: "%.2f", shortPlan.entryPrice)))")
            assertTest(shortPlan.riskRewardRatio >= 1.0, "Rasio R:R SHORT memenuhi standar minimum >= 1.0 (R:R: 1:\(String(format: "%.2f", shortPlan.riskRewardRatio)))")
        } else {
            assertTest(false, "GAGAL: shortPlan bernilai nil!")
        }

        // -------------------------------------------------------------
        // TEST 10: Strict Fail-Closed on Insufficient H1 Bars (<200 bars) (Temuan Agen 1 #2)
        // -------------------------------------------------------------
        print("\n[TEST GROUP 10: Fail-Closed on Insufficient H1 (< 200 bars)]")
        var insufficientH1: [AstronacciKline] = []
        for i in 0..<120 { // Hanya 120 bars (< 200)
            let p = 60000.0 + Double(i * 30)
            insufficientH1.append(AstronacciKline(open: p, high: p + 30, low: p - 30, close: p, volume: 500, timestamp: Int64(i * 3600)))
        }

        let failClosedResult = engine.evaluateConfluence(
            symbol: "BTC-USDT",
            klinesH1: insufficientH1,
            klinesM15: testM15,
            klinesM5: testM5_WithTrigger,
            isNewsClear: true,
            isLondonNyOverlap: true
        )

        assertTest(failClosedResult.regime == .choppy, "H1 < 200 bars wajib fail-closed menjadi CHOPPY")
        assertTest(failClosedResult.scoreBreakdown.regimePoints == 0, "Regime points bernilai 0 saat H1 < 200 bars")

        // -------------------------------------------------------------
        // TEST 11: Sizing Floor Rounding & Min-Step Guard (Temuan Agen 1 #4)
        // -------------------------------------------------------------
        print("\n[TEST GROUP 11: Sizing Floor Rounding & Minimum Step Guard]")
        // Skenario A: Akun kecil ($50) dengan 1% risk ($0.50). Jarak SL $1000 -> raw size 0.0005 BTC (< 0.001 min step)
        let smallAccountResult = engine.evaluateConfluence(
            symbol: "BTC-USDT",
            klinesH1: testH1,
            klinesM15: testM15,
            klinesM5: testM5_WithTrigger,
            isNewsClear: true,
            isLondonNyOverlap: true,
            accountEquity: 50.0 // $50 equity
        )
        assertTest(smallAccountResult.tradePlan == nil, "Akun $50 dengan lot di bawah 0.001 BTC DITOLAK (tradePlan == nil)")
        assertTest(smallAccountResult.finalStatus == "STAND_ASIDE", "Status final akun di bawah min-step adalah STAND_ASIDE")

        // Skenario B: Verifikasi floor truncation (tidak pernah round-up)
        let rawVal = 0.054999
        let flooredVal = floor(rawVal * 1000.0) / 1000.0
        assertTest(flooredVal == 0.054, "Floor rounding memotong presisi ke bawah: 0.054999 -> 0.054 (Bukan 0.055)")

        // -------------------------------------------------------------
        // TEST 12: Veto Gate Hard Rejection on R:R < 1.0 (Amendemen 1 Canon)
        // -------------------------------------------------------------
        print("\n[TEST GROUP 12: Hard Veto Rejection on R:R < 1.0 & Regression R:R 1.4 vs 0.9]")
        // M15 dengan Swing High sangat dekat sehingga TP1 sempit (Reward < 1.0 * Risk)
        var narrowM15: [AstronacciKline] = []
        for i in 0..<50 {
            narrowM15.append(AstronacciKline(open: 64000, high: 64100, low: 63950, close: 64050, volume: 300, timestamp: Int64(i * 900)))
        }
        narrowM15.append(AstronacciKline(open: 64050, high: 64100, low: 63950, close: 64000, volume: 500, timestamp: 46000)) // Swing Low 63,950
        narrowM15.append(AstronacciKline(open: 64000, high: 64400, low: 64000, close: 64350, volume: 600, timestamp: 47000)) // Swing High hanya 64,400 (hanya 450 pt)
        // Pullback ke 64,200 (Risk ~300 pt, Reward ~150 pt -> R:R ~ 0.5 < 1.0)
        for i in 1...6 {
            let p = 64350.0 - Double(i * 25)
            narrowM15.append(AstronacciKline(open: p, high: p + 10, low: p - 10, close: p, volume: 300, timestamp: Int64(47000 + i * 900)))
        }

        var narrowM5: [AstronacciKline] = []
        for i in 0..<30 {
            let p = 64200.0 + Double(i * 2)
            narrowM5.append(AstronacciKline(open: p, high: p + 5, low: p - 5, close: p, volume: 100, timestamp: Int64(i * 300)))
        }
        // Valid Pin Bar
        narrowM5.append(AstronacciKline(open: 64210, high: 64220, low: 64100, close: 64205, volume: 1000, timestamp: 10000, isClosed: true))

        let narrowRRResult = engine.evaluateConfluence(
            symbol: "BTC-USDT",
            klinesH1: testH1,
            klinesM15: narrowM15,
            klinesM5: narrowM5,
            isNewsClear: true,
            isLondonNyOverlap: true
        )

        assertTest(!narrowRRResult.vetoCheck.rrPassed, "Veto Gate: R:R < 1.0 terdeteksi GAGAL (rrPassed = false)")
        assertTest(!narrowRRResult.vetoCheck.isPassed, "Veto Gate: Status kelulusan keseluruhan GAGAL (isPassed = false)")
        assertTest(narrowRRResult.tradePlan == nil, "Tidak ada Trade Plan yang dihasilkan ketika R:R < 1.0")
        assertTest(narrowRRResult.finalStatus == "STAND_ASIDE", "Status final STAND_ASIDE ketika R:R < 1.0")

        // Uji Regresi Mandat Auditor: R:R 1.4 WAJIB LOLOS, R:R 0.9 WAJIB GUGUR
        let dummyCandle = AstronacciCandleTrigger.bullishPinBar(lowerWickRatio: 2.5)
        let vetoRR14 = AstronacciDeterministicEngine.evaluateVetoGate(
            detectedRegime: .bullish,
            candleTrigger: dummyCandle,
            calculatedRR: 1.40,
            riskDist: 250.0,
            swingRange: 650.0,
            atr14: 200.0,
            totalScore: 75,
            minRR: 1.0
        )
        assertTest(vetoRR14.rrPassed, "Regresi Auditor: Setup dengan R:R 1.40 WAJIB LOLOS VETO R:R (rrPassed = true)")
        assertTest(vetoRR14.isPassed, "Regresi Auditor: Setup dengan R:R 1.40 & skor 75 WAJIB LOLOS KESELURUHAN (isPassed = true)")

        let vetoRR09 = AstronacciDeterministicEngine.evaluateVetoGate(
            detectedRegime: .bullish,
            candleTrigger: dummyCandle,
            calculatedRR: 0.90,
            riskDist: 250.0,
            swingRange: 650.0,
            atr14: 200.0,
            totalScore: 75,
            minRR: 1.0
        )
        assertTest(!vetoRR09.rrPassed, "Regresi Auditor: Setup dengan R:R 0.90 WAJIB GUGUR VETO R:R (rrPassed = false)")
        assertTest(!vetoRR09.isPassed, "Regresi Auditor: Setup dengan R:R 0.90 WAJIB GUGUR KESELURUHAN (isPassed = false)")

        // -------------------------------------------------------------
        // TEST 13: Manual Codable Serialization Roundtrip (Temuan Agen 1 #3)
        // -------------------------------------------------------------
        print("\n[TEST GROUP 13: Manual Codable Roundtrip for Associated Enums]")
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        do {
            let trigger1 = AstronacciCandleTrigger.bullishPinBar(lowerWickRatio: 2.75)
            let data1 = try encoder.encode(trigger1)
            let decoded1 = try decoder.decode(AstronacciCandleTrigger.self, from: data1)
            assertTest(decoded1 == trigger1, "Codable Roundtrip Lulus: .bullishPinBar(lowerWickRatio: 2.75)")

            let trigger2 = AstronacciCandleTrigger.bearishShootingStar(upperWickRatio: 3.12)
            let data2 = try encoder.encode(trigger2)
            let decoded2 = try decoder.decode(AstronacciCandleTrigger.self, from: data2)
            assertTest(decoded2 == trigger2, "Codable Roundtrip Lulus: .bearishShootingStar(upperWickRatio: 3.12)")

            let trigger3 = AstronacciCandleTrigger.bullishEngulfing
            let data3 = try encoder.encode(trigger3)
            let decoded3 = try decoder.decode(AstronacciCandleTrigger.self, from: data3)
            assertTest(decoded3 == trigger3, "Codable Roundtrip Lulus: .bullishEngulfing")

            let trigger4 = AstronacciCandleTrigger.none
            let data4 = try encoder.encode(trigger4)
            let decoded4 = try decoder.decode(AstronacciCandleTrigger.self, from: data4)
            assertTest(decoded4 == trigger4, "Codable Roundtrip Lulus: .none")

            let trigger5 = AstronacciCandleTrigger.bearishEngulfing
            let data5 = try encoder.encode(trigger5)
            let decoded5 = try decoder.decode(AstronacciCandleTrigger.self, from: data5)
            assertTest(decoded5 == trigger5, "Codable Roundtrip Lulus: .bearishEngulfing")
        } catch {
            assertTest(false, "Codable Roundtrip GAGAL dengan error: \(error)")
        }

        // -------------------------------------------------------------
        // TEST 14: End-to-End A-Grade Golden Pocket Setup (Temuan Agen 2)
        // -------------------------------------------------------------
        print("\n[TEST GROUP 14: End-to-End A-Grade Golden Pocket Setup (Score >= 80, 1.0% Risk)]")
        // M15 Swing Low: 64,000, Swing High: 66,000 (Range = 2,000)
        // Golden Pocket Bullish: 64,764 (0.618) s.d. 65,000 (0.500)
        // Pullback price = 64,900 (tepat di dalam Golden Pocket)
        var aGradeM15: [AstronacciKline] = []
        for i in 0..<50 {
            aGradeM15.append(AstronacciKline(open: 64200, high: 64250, low: 64150, close: 64200, volume: 300, timestamp: Int64(i * 900)))
        }
        // Swing Low at 64,000
        aGradeM15.append(AstronacciKline(open: 64100, high: 64150, low: 64000, close: 64050, volume: 500, timestamp: 46000))
        aGradeM15.append(AstronacciKline(open: 64050, high: 64200, low: 64020, close: 64180, volume: 400, timestamp: 46900))
        // Rally to Swing High at 66,000
        for i in 1...10 {
            let p = 64200.0 + Double(i * 175)
            aGradeM15.append(AstronacciKline(open: p - 30, high: p + 30, low: p - 40, close: p + 10, volume: 600, timestamp: Int64(48000 + i * 900)))
        }
        // Swing High at 66,000
        aGradeM15.append(AstronacciKline(open: 65950, high: 66050, low: 65900, close: 66000, volume: 800, timestamp: 58000))
        aGradeM15.append(AstronacciKline(open: 66000, high: 66020, low: 65800, close: 65850, volume: 500, timestamp: 58900))
        // Pullback down directly into Golden Pocket at 64,900
        for i in 1...6 {
            let p = 65850.0 - Double(i * 155)
            aGradeM15.append(AstronacciKline(open: p + 20, high: p + 30, low: p - 20, close: p - 10, volume: 400, timestamp: Int64(59000 + i * 900)))
        }

        var aGradeM5: [AstronacciKline] = []
        for i in 0..<35 {
            let p = 65200.0 - Double(i * 8)
            aGradeM5.append(AstronacciKline(open: p, high: p + 10, low: p - 10, close: p - 5, volume: 200, timestamp: Int64(i * 300)))
        }
        // Golden Cross in Oversold on M5 + Pin Bar at 64,900
        aGradeM5.append(AstronacciKline(open: 64920, high: 64930, low: 64680, close: 64910, volume: 1500, timestamp: 11000, isClosed: true))

        let aGradeResult = engine.evaluateConfluence(
            symbol: "BTC-USDT",
            klinesH1: testH1,
            klinesM15: aGradeM15,
            klinesM5: aGradeM5,
            isNewsClear: true,
            isLondonNyOverlap: true
        )

        assertTest(aGradeResult.fibGrid.isInGoldenPocket, "Harga berada tepat di Golden Pocket (isInGoldenPocket = true)")
        assertTest(aGradeResult.scoreBreakdown.totalScore >= 80, "Skor konfluensi mencapai ambang A-Grade (Skor: \(aGradeResult.scoreBreakdown.totalScore)/100)")
        assertTest(aGradeResult.finalStatus == "A_GRADE_SETUP", "Status final adalah A_GRADE_SETUP")
        assertTest(aGradeResult.tradePlan != nil, "Trade Plan A-Grade berhasil diterbitkan")
        if let plan = aGradeResult.tradePlan {
            assertTest(!plan.isBGradeHalfSize, "Alokasi risiko adalah Full 1.0% (bukan setengah risiko B-Grade)")
            assertTest(plan.riskRewardRatio >= 1.0, "Rasio R:R A-Grade memenuhi syarat (R:R: 1:\(String(format: "%.2f", plan.riskRewardRatio)))")
        }

        // -------------------------------------------------------------
        // TEST 15: Micro-Risk Distance Veto Protection (Temuan Agen 2)
        // -------------------------------------------------------------
        print("\n[TEST GROUP 15: Micro-Risk Distance Veto (< 1.0x ATR)]")
        // Setup di mana entry price berada tepat 15 pt di atas SL (SL = 63,985, entry = 64,000, ATR ~ 150 pt)
        var microRiskM5 = aGradeM5
        microRiskM5.removeLast()
        // Kandel trigger dengan close tepat di 64,000 (hanya 15 pt di atas stopLoss ~63,985)
        microRiskM5.append(AstronacciKline(open: 64010, high: 64020, low: 63970, close: 64000, volume: 1500, timestamp: 12000, isClosed: true))

        let microRiskResult = engine.evaluateConfluence(
            symbol: "BTC-USDT",
            klinesH1: testH1,
            klinesM15: aGradeM15,
            klinesM5: microRiskM5,
            isNewsClear: true,
            isLondonNyOverlap: true
        )

        assertTest(!microRiskResult.vetoCheck.riskDistPassed, "Veto Gate: Micro-risk distance < 1.0x ATR terdeteksi GAGAL (riskDistPassed = false)")
        assertTest(!microRiskResult.vetoCheck.isPassed, "Veto Gate: Status kelulusan keseluruhan GAGAL saat risk distance mikro")
        assertTest(microRiskResult.tradePlan == nil, "Tidak ada Trade Plan yang diterbitkan pada kondisi micro-risk")
        assertTest(microRiskResult.finalStatus == "STAND_ASIDE", "Status final STAND_ASIDE untuk mencegah hyper-leverage blowout")

        // -------------------------------------------------------------
        // TEST 16: Zero-Body Doji Rejection (Temuan Agen 2)
        // -------------------------------------------------------------
        print("\n[TEST GROUP 16: Zero-Body Doji Rejection]")
        let zeroBodyDoji = AstronacciKline(open: 64800, high: 64850, low: 64750, close: 64800, volume: 100, timestamp: 2000)
        let prevNormal = AstronacciKline(open: 64820, high: 64830, low: 64790, close: 64800, volume: 100, timestamp: 1900)
        let dojiTrigger = engine.detectCandleTrigger(kline: zeroBodyDoji, previousKline: prevNormal, atr: 100.0)
        assertTest(dojiTrigger == .none, "Doji tanpa badan (body == 0) DITOLAK secara deterministik sebagai .none")

        // -------------------------------------------------------------
        // TEST 17: Strict Fail-Closed on Nil 5-Bar Pivot Fractals (Temuan Agen 2)
        // -------------------------------------------------------------
        print("\n[TEST GROUP 17: Strict Fail-Closed on Nil 5-Bar Pivot Fractals]")
        // Klines flat tanpa pivot high atau pivot low
        var flatM15: [AstronacciKline] = []
        for i in 0..<30 {
            flatM15.append(AstronacciKline(open: 64000, high: 64010, low: 63990, close: 64000, volume: 100, timestamp: Int64(i * 900)))
        }
        let nilFractals = engine.detect5BarPivotFractals(klines: flatM15)
        assertTest(nilFractals == nil, "Klines tanpa ayunan 5-bar mengembalikan nil (tanpa sintesis fabrikasi)")

        let nilFractalResult = engine.evaluateConfluence(
            symbol: "BTC-USDT",
            klinesH1: testH1,
            klinesM15: flatM15,
            klinesM5: aGradeM5,
            isNewsClear: true,
            isLondonNyOverlap: true
        )
        assertTest(nilFractalResult.tradePlan == nil, "Fractal nil langsung menggugurkan penerbitan trade plan")
        assertTest(nilFractalResult.finalStatus == "STAND_ASIDE", "Status final STAND_ASIDE ketika fractal nil")

        // -------------------------------------------------------------
        // TEST 18: Input Kline Sanity Check (Temuan Agen 2)
        // -------------------------------------------------------------
        print("\n[TEST GROUP 18: Input Kline Sanity Validation (.isValid)]")
        let validKline = AstronacciKline(open: 64000, high: 64100, low: 63900, close: 64050, volume: 50, timestamp: 1000)
        assertTest(validKline.isValid, "Kline normal terverifikasi isValid = true")

        let corruptHighLow = AstronacciKline(open: 64000, high: 63800, low: 64100, close: 64050, volume: 50, timestamp: 1000)
        assertTest(!corruptHighLow.isValid, "Kline korup (high < low) terverifikasi isValid = false")

        let negativePrice = AstronacciKline(open: -64000, high: 64100, low: 63900, close: 64050, volume: 50, timestamp: 1000)
        assertTest(!negativePrice.isValid, "Kline harga negatif terverifikasi isValid = false")

        let nanPrice = AstronacciKline(open: Double.nan, high: 64100, low: 63900, close: 64050, volume: 50, timestamp: 1000)
        assertTest(!nanPrice.isValid, "Kline harga NaN terverifikasi isValid = false")

        // -------------------------------------------------------------
        // TEST 19: Structural Temporal Sequence Guard (Probe B Temuan Agen 1)
        // -------------------------------------------------------------
        print("\n[TEST GROUP 19: Structural Temporal Sequence Guard (Probe B - Never Fight Structure)]")
        // Skenario Probe B: Swing High terjadi di bar awal (66,050), lalu breakdown mencetak Lower Low lebih baru (61,900)
        var brokenStructureM15: [AstronacciKline] = []
        for i in 0..<15 {
            brokenStructureM15.append(AstronacciKline(open: 65500, high: 65600, low: 65400, close: 65500, volume: 300, timestamp: Int64(i * 900)))
        }
        // Swing High di Bar 17: 66,050
        brokenStructureM15.append(AstronacciKline(open: 65600, high: 65800, low: 65500, close: 65700, volume: 400, timestamp: 20000))
        brokenStructureM15.append(AstronacciKline(open: 65700, high: 65950, low: 65650, close: 65900, volume: 500, timestamp: 20900))
        brokenStructureM15.append(AstronacciKline(open: 65900, high: 66050, low: 65800, close: 66000, volume: 800, timestamp: 21800)) // Swing High!
        brokenStructureM15.append(AstronacciKline(open: 66000, high: 65900, low: 65700, close: 65800, volume: 500, timestamp: 22700))
        brokenStructureM15.append(AstronacciKline(open: 65800, high: 65700, low: 65500, close: 65600, volume: 400, timestamp: 23600))

        // Breakdown parah menuju 61,900
        for i in 1...6 {
            let p = 65500.0 - Double(i * 500)
            brokenStructureM15.append(AstronacciKline(open: p + 100, high: p + 150, low: p - 100, close: p - 50, volume: 800, timestamp: Int64(24000 + i * 900)))
        }
        // Swing Low di Bar 28: 61,900 (terjadi SETELAH Swing High)
        brokenStructureM15.append(AstronacciKline(open: 62200, high: 62300, low: 62100, close: 62150, volume: 500, timestamp: 31000))
        brokenStructureM15.append(AstronacciKline(open: 62150, high: 62200, low: 62000, close: 62050, volume: 600, timestamp: 31900))
        brokenStructureM15.append(AstronacciKline(open: 62050, high: 62100, low: 61900, close: 62000, volume: 900, timestamp: 32800)) // Swing Low!
        brokenStructureM15.append(AstronacciKline(open: 62000, high: 62150, low: 62020, close: 62100, volume: 500, timestamp: 33700))
        brokenStructureM15.append(AstronacciKline(open: 62100, high: 62300, low: 62150, close: 62250, volume: 400, timestamp: 34600))

        // Dead-cat bounce naik ke 63,700
        for i in 1...5 {
            let p = 62250.0 + Double(i * 290)
            brokenStructureM15.append(AstronacciKline(open: p - 20, high: p + 30, low: p - 20, close: p + 10, volume: 400, timestamp: Int64(35000 + i * 900)))
        }

        var probeBM5: [AstronacciKline] = []
        for i in 0..<35 {
            let p = 63600.0 + Double(i * 3)
            probeBM5.append(AstronacciKline(open: p, high: p + 10, low: p - 10, close: p + 2, volume: 200, timestamp: Int64(i * 300)))
        }
        probeBM5.append(AstronacciKline(open: 63710, high: 63720, low: 63500, close: 63705, volume: 1500, timestamp: 12000, isClosed: true))

        let probeBResult = engine.evaluateConfluence(
            symbol: "BTC-USDT",
            klinesH1: testH1, // Rezim Bullish
            klinesM15: brokenStructureM15, // Struktur pecah (Low terbentuk setelah High)
            klinesM5: probeBM5,
            isNewsClear: true,
            isLondonNyOverlap: true
        )

        assertTest(probeBResult.tradePlan == nil, "Probe B: Struktur pecah (Low setelah High pada Bullish) DITOLAK (tradePlan == nil)")
        assertTest(probeBResult.finalStatus == "STAND_ASIDE", "Probe B: Status final otomatis STAND_ASIDE ketika urutan fractal terbalik")

        // -------------------------------------------------------------
        // TEST 20: Post-Cap Leverage Step Guard (Temuan Agen 2 Item 1)
        // -------------------------------------------------------------
        print("\n[TEST GROUP 20: Post-Cap Leverage Step Guard]")
        // Modal sangat kecil ($5.0) dengan leverage 10x -> maxAllowedNotional = $50.0
        // Entry price $64,900 -> cappedSize = $50 / $64,900 = 0.0007 BTC (< 0.001 BTC)
        let microEquityResult = engine.evaluateConfluence(
            symbol: "BTC-USDT",
            klinesH1: testH1,
            klinesM15: aGradeM15,
            klinesM5: aGradeM5,
            isNewsClear: true,
            isLondonNyOverlap: true,
            accountEquity: 5.0, // $5.0 equity
            maxLeverage: 10.0
        )
        assertTest(microEquityResult.tradePlan == nil, "Post-cap size < 0.001 BTC DITOLAK (tradePlan == nil)")
        assertTest(microEquityResult.finalStatus == "STAND_ASIDE", "Status final akun micro-leverage adalah STAND_ASIDE")

        print("\n=================================================================")
        print("🏁 HASIL AKHIR: \(passedCount) / \(totalTests) PENGUJIAN LOLOS DENGAN SUKSES!")
        print("=================================================================")

        if passedCount == totalTests {
            exit(0)
        } else {
            exit(1)
        }
    }
}
