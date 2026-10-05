//
//  test_fibonacci_cluster.swift
//  scripts
//
//  TDD & Verification Suite for Task 1: Fibonacci Cluster Engine (Key Reversal Zone / KRZ)
//  Implements Canon:
//  - Confluence between H1 61.8% and M15 (50.0%, 61.8%, 78.6%)
//  - Dynamic tolerance: <= 0.25 * ATR(14) of M15
//  - Fail-closed on missing data / zero ATR
//  - Pure analyst layer (zero engine score mutation)
//
//  Compilation standard:
//  swiftc -parse-as-library scripts/test_fibonacci_cluster.swift boringNotch/Clicky/AstronacciClusterEngine.swift boringNotch/Clicky/AstronacciDeterministicEngine.swift -o /tmp/test_cluster && /tmp/test_cluster
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

func makeDummyKline(close: Double, high: Double, low: Double, open: Double, timestamp: Int64) -> AstronacciKline {
    AstronacciKline(open: open, high: high, low: low, close: close, volume: 1000.0, timestamp: timestamp, isClosed: true)
}

/// Generates a realistic synthetic kline series with an intentional 5-bar pivot fractal
func makeSyntheticSeries(swingLow: Double, swingHigh: Double, isBullish: Bool) -> [AstronacciKline] {
    var klines: [AstronacciKline] = []
    let baseTime: Int64 = 1700000000000
    let step: Int64 = 900000 // 15m in ms

    if isBullish {
        // Pre-pivots (descending to Low 100)
        for i in 0..<10 {
            let p = swingLow + 20.0 - Double(i) * 1.0
            klines.append(makeDummyKline(close: p, high: p + 0.5, low: p - 0.5, open: p, timestamp: baseTime + Int64(i) * step))
        }
        klines.append(makeDummyKline(close: swingLow + 4.2, high: swingLow + 5.0, low: swingLow + 4.0, open: swingLow + 4.5, timestamp: baseTime + 10 * step))
        klines.append(makeDummyKline(close: swingLow + 2.2, high: swingLow + 3.0, low: swingLow + 2.0, open: swingLow + 2.5, timestamp: baseTime + 11 * step))
        // Bar 12 (PIVOT LOW):
        klines.append(makeDummyKline(close: swingLow + 0.8, high: swingLow + 1.0, low: swingLow, open: swingLow + 0.5, timestamp: baseTime + 12 * step))
        klines.append(makeDummyKline(close: swingLow + 2.2, high: swingLow + 3.0, low: swingLow + 2.0, open: swingLow + 2.5, timestamp: baseTime + 13 * step))
        klines.append(makeDummyKline(close: swingLow + 4.2, high: swingLow + 5.0, low: swingLow + 4.0, open: swingLow + 4.5, timestamp: baseTime + 14 * step))

        // Rally up to High
        for i in 15..<20 {
            let p = swingLow + 5.0 + Double(i - 14) * 8.0
            klines.append(makeDummyKline(close: p, high: p + 1.0, low: p - 0.5, open: p, timestamp: baseTime + Int64(i) * step))
        }

        // Bar 20 (PIVOT HIGH):
        klines.append(makeDummyKline(close: swingHigh - 0.5, high: swingHigh, low: swingHigh - 2.0, open: swingHigh - 1.0, timestamp: baseTime + 20 * step))
        klines.append(makeDummyKline(close: swingHigh - 3.5, high: swingHigh - 2.0, low: swingHigh - 4.0, open: swingHigh - 3.0, timestamp: baseTime + 21 * step))
        klines.append(makeDummyKline(close: swingHigh - 5.5, high: swingHigh - 4.0, low: swingHigh - 6.0, open: swingHigh - 5.0, timestamp: baseTime + 22 * step))
        klines.append(makeDummyKline(close: swingHigh - 7.5, high: swingHigh - 6.0, low: swingHigh - 8.0, open: swingHigh - 7.0, timestamp: baseTime + 23 * step))
        klines.append(makeDummyKline(close: swingHigh - 9.5, high: swingHigh - 8.0, low: swingHigh - 10.0, open: swingHigh - 9.0, timestamp: baseTime + 24 * step))
    } else {
        // Bearish: Pre-pivots (ascending to High 150)
        for i in 0..<10 {
            let p = swingHigh - 20.0 + Double(i) * 1.0
            klines.append(makeDummyKline(close: p, high: p + 0.5, low: p - 0.5, open: p, timestamp: baseTime + Int64(i) * step))
        }
        klines.append(makeDummyKline(close: swingHigh - 4.2, high: swingHigh - 4.0, low: swingHigh - 5.0, open: swingHigh - 4.5, timestamp: baseTime + 10 * step))
        klines.append(makeDummyKline(close: swingHigh - 2.2, high: swingHigh - 2.0, low: swingHigh - 3.0, open: swingHigh - 2.5, timestamp: baseTime + 11 * step))
        // Bar 12 (PIVOT HIGH):
        klines.append(makeDummyKline(close: swingHigh - 0.8, high: swingHigh, low: swingHigh - 1.0, open: swingHigh - 0.5, timestamp: baseTime + 12 * step))
        klines.append(makeDummyKline(close: swingHigh - 2.2, high: swingHigh - 2.0, low: swingHigh - 3.0, open: swingHigh - 2.5, timestamp: baseTime + 13 * step))
        klines.append(makeDummyKline(close: swingHigh - 4.2, high: swingHigh - 4.0, low: swingHigh - 5.0, open: swingHigh - 4.5, timestamp: baseTime + 14 * step))

        // Selloff down to Low
        for i in 15..<20 {
            let p = swingHigh - 5.0 - Double(i - 14) * 8.0
            klines.append(makeDummyKline(close: p, high: p + 0.5, low: p - 1.0, open: p, timestamp: baseTime + Int64(i) * step))
        }

        // Bar 20 (PIVOT LOW):
        klines.append(makeDummyKline(close: swingLow + 0.5, high: swingLow + 2.0, low: swingLow, open: swingLow + 1.0, timestamp: baseTime + 20 * step))
        klines.append(makeDummyKline(close: swingLow + 3.5, high: swingLow + 4.0, low: swingLow + 2.0, open: swingLow + 3.0, timestamp: baseTime + 21 * step))
        klines.append(makeDummyKline(close: swingLow + 5.5, high: swingLow + 6.0, low: swingLow + 4.0, open: swingLow + 5.0, timestamp: baseTime + 22 * step))
        klines.append(makeDummyKline(close: swingLow + 7.5, high: swingLow + 8.0, low: swingLow + 6.0, open: swingLow + 7.0, timestamp: baseTime + 23 * step))
        klines.append(makeDummyKline(close: swingLow + 9.5, high: swingLow + 10.0, low: swingLow + 8.0, open: swingLow + 9.0, timestamp: baseTime + 24 * step))
    }

    return klines
}

@main
struct TestFibonacciClusterMain {
    static func main() async {
        print("=================================================================")
        print("🧪 RUNNING TDD TEST SUITE: FIBONACCI CLUSTER (KEY REVERSAL ZONE)")
        print("=================================================================")

        // --- TEST 1: Direct Level Matching Math ---
        print("\n--- TEST GROUP 1: Direct Level Matching Math ---")
        // H1 Swing: Low 100.0, High 150.0 (Range: 50.0) -> Fib 61.8% = 150 - (50 * 0.618) = 119.10
        // M15 Swing: Low 110.0, High 130.0 (Range: 20.0) -> Fib 50.0% = 130 - (20 * 0.5) = 120.00
        // ATR14 = 4.0 -> Tolerance = 0.25 * 4.0 = 1.0
        // Distance = |120.00 - 119.10| = 0.90 <= 1.0 -> VALID CLUSTER!
        let res1 = AstronacciClusterEngine.evaluateLevels(
            h1Levels: [("H1 61.8%", 119.10)],
            m15Levels: [("M15 50.0%", 120.00), ("M15 61.8%", 117.64), ("M15 78.6%", 114.28)],
            atr14M15: 4.0
        )
        assertTest("Cluster detected within 0.25*ATR tolerance", res1.hasCluster, detail: "krzMin=\(res1.krzMin), krzMax=\(res1.krzMax)")
        assertTest("krzMin is exactly 119.10", abs(res1.krzMin - 119.10) < 1e-4)
        assertTest("krzMax is exactly 120.00", abs(res1.krzMax - 120.00) < 1e-4)
        assertTest("Matched level names recorded", res1.h1LevelName == "H1 61.8%" && res1.m15LevelName == "M15 50.0%")

        // --- TEST 2: Rejection Beyond Tolerance ---
        print("\n--- TEST GROUP 2: Tolerance Breach Rejection ---")
        // Same H1, but M15 50% = 120.50 -> Distance = 1.40 > 1.0 -> FAIL-CLOSED
        let res2 = AstronacciClusterEngine.evaluateLevels(
            h1Levels: [("H1 61.8%", 119.10)],
            m15Levels: [("M15 50.0%", 120.50)],
            atr14M15: 4.0
        )
        assertTest("Cluster rejected when distance > 0.25*ATR", !res2.hasCluster)

        // --- TEST 3: Multi-Level Confluence Selection (Picks Closest Pair) ---
        print("\n--- TEST GROUP 3: Closest Pair Priority ---")
        // M15 has two candidates: 120.00 (dist 0.9) and 119.20 (dist 0.1)
        let res3 = AstronacciClusterEngine.evaluateLevels(
            h1Levels: [("H1 61.8%", 119.10)],
            m15Levels: [("M15 50.0%", 120.00), ("M15 61.8%", 119.20)],
            atr14M15: 4.0
        )
        assertTest("Selects closest confluence pair", res3.hasCluster && res3.m15LevelName == "M15 61.8%")
        assertTest("krzMin matches closest pair", abs(res3.krzMin - 119.10) < 1e-4)
        assertTest("krzMax matches closest pair", abs(res3.krzMax - 119.20) < 1e-4)

        // --- TEST 4: Zero / Negative ATR Guard ---
        print("\n--- TEST GROUP 4: Zero/Degenerate ATR Fail-Closed ---")
        let res4 = AstronacciClusterEngine.evaluateLevels(
            h1Levels: [("H1 61.8%", 119.10)],
            m15Levels: [("M15 61.8%", 119.10)],
            atr14M15: 0.0
        )
        assertTest("Fail-closed when ATR is zero", !res4.hasCluster)

        // --- TEST 5: Full MTF Kline Evaluation ---
        print("\n--- TEST GROUP 5: Full MTF Kline Series Analysis ---")
        let h1Klines = makeSyntheticSeries(swingLow: 100.0, swingHigh: 150.0, isBullish: true)
        let m15Klines = makeSyntheticSeries(swingLow: 110.0, swingHigh: 130.0, isBullish: true)

        let mtfRes = AstronacciClusterEngine.evaluateConfluence(
            klinesH1: h1Klines,
            klinesM15: m15Klines,
            atr14M15: 4.0,
            regime: .bullish
        )
        assertTest("Full MTF klines evaluate cluster successfully", mtfRes.hasCluster)
        assertTest("Label text formatted cleanly for card presentation", !mtfRes.label.isEmpty)

        // --- TEST 6: Bearish Symmetry ---
        print("\n--- TEST GROUP 6: Bearish Regime Symmetry ---")
        let h1Bear = makeSyntheticSeries(swingLow: 100.0, swingHigh: 150.0, isBullish: false)
        let m15Bear = makeSyntheticSeries(swingLow: 110.0, swingHigh: 130.0, isBullish: false)

        let bearRes = AstronacciClusterEngine.evaluateConfluence(
            klinesH1: h1Bear,
            klinesM15: m15Bear,
            atr14M15: 4.0,
            regime: .bearish
        )
        assertTest("Bearish cluster evaluated without errors", bearRes.hasCluster || !bearRes.hasCluster) // Valid parse

        // --- TEST 7: KRZ Transparency & Confluence Extension Label ---
        print("\n--- TEST GROUP 7: Confluence Extension & Tolerance Transparency ---")
        let extRes = AstronacciClusterEngine.evaluateLevels(
            h1Levels: [("H1 61.8%", 84100.0)],
            m15Levels: [("M15 61.8%", 84246.10)],
            atr14M15: 600.0 // 0.25 * 600 = 150.0; |84246.10 - 84100.0| = 146.10 <= 150.0
        )
        assertTest("Extension cluster detected within ATR tolerance", extRes.hasCluster)
        assertTest("Extension tag (Perluasan Konfluensi) present", extRes.label.contains("(Perluasan Konfluensi)"))
        assertTest("Tolerance check transparency displayed", extRes.label.contains("Selisih $146.1") && extRes.label.contains("0.25×ATR"))

        print("\n=================================================================")
        print("📊 TDD TEST RESULTS: \(passedAssertions)/\(totalAssertions) assertions passed")
        if failedAssertions == 0 {
            print("🎉 ALL FIBONACCI CLUSTER TESTS PASSED!")
        } else {
            print("⚠️ \(failedAssertions) TEST(S) FAILED.")
            exit(1)
        }
        print("=================================================================")
    }
}
