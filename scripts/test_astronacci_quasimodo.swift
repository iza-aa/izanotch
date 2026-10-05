import Foundation

@main
struct TestAstronacciQuasimodo {
    static func main() {
        print("=================================================================")
        print("🧪 UJI TDD ASTRONACCI QUASIMODO (QM / OVER-UNDER) RECOGNIZER")
        print("=================================================================")

        let engine = AstronacciQuasimodoEngine()

        // Test 1: Bullish Quasimodo (Over-Under Bottom Reversal)
        print("\n[TEST 1: BULLISH QUASIMODO]")
        let bullResult = engine.evaluatePattern(
            p1Price: 100.0, // Left Shoulder (Low 1)
            p1Index: 5,
            p2Price: 110.0, // High 1
            p2Index: 10,
            p3Price: 94.0,  // Head (Lower Low < 100.0)
            p3Index: 15,
            p4Price: 116.0, // BOS (Higher High > 110.0)
            p4Index: 20,
            currentPrice: 100.2,
            atr: 2.0,
            isBullishStructure: true
        )

        assert(bullResult.type == .bullish, "Expected bullish QM, got \(bullResult.type)")
        assert(bullResult.isBullish == true, "Expected isBullish == true")
        assert(bullResult.leftShoulderPrice == 100.0, "Expected LS 100.0, got \(bullResult.leftShoulderPrice)")
        assert(bullResult.headPrice == 94.0, "Expected Head 94.0, got \(bullResult.headPrice)")
        assert(bullResult.bosPrice == 116.0, "Expected BOS 116.0, got \(bullResult.bosPrice)")
        assert(bullResult.invalidationPrice == 94.0, "Expected SL at Head 94.0")
        assert(bullResult.isRetestingNow == true, "Expected isRetestingNow == true (current 100.2 vs LS 100.0)")
        print("  ✅ [PASS] Bullish Quasimodo terdeteksi presisi (LS: $100.0, Head: $94.0, BOS: $116.0)")

        // Test 2: Bearish Quasimodo (Over-Under Top Reversal)
        print("\n[TEST 2: BEARISH QUASIMODO]")
        let bearResult = engine.evaluatePattern(
            p1Price: 100.0, // Left Shoulder (High 1)
            p1Index: 5,
            p2Price: 90.0,  // Low 1
            p2Index: 10,
            p3Price: 106.0, // Head (Higher High > 100.0)
            p3Index: 15,
            p4Price: 84.0,  // BOS (Lower Low < 90.0)
            p4Index: 20,
            currentPrice: 99.8,
            atr: 2.0,
            isBullishStructure: false
        )

        assert(bearResult.type == .bearish, "Expected bearish QM, got \(bearResult.type)")
        assert(bearResult.isBullish == false, "Expected isBullish == false")
        assert(bearResult.leftShoulderPrice == 100.0, "Expected LS 100.0")
        assert(bearResult.headPrice == 106.0, "Expected Head 106.0")
        assert(bearResult.bosPrice == 84.0, "Expected BOS 84.0")
        assert(bearResult.invalidationPrice == 106.0, "Expected SL at Head 106.0")
        assert(bearResult.isRetestingNow == true, "Expected isRetestingNow == true")
        print("  ✅ [PASS] Bearish Quasimodo terdeteksi presisi (LS: $100.0, Head: $106.0, BOS: $84.0)")

        // Test 3: Failed Quasimodo - Head did not sweep liquidity (Higher Low instead of Lower Low)
        print("\n[TEST 3: REJECTED PATTERN (NO LIQUIDITY SWEEP ON HEAD)]")
        let nonSweepResult = engine.evaluatePattern(
            p1Price: 100.0,
            p1Index: 5,
            p2Price: 110.0,
            p2Index: 10,
            p3Price: 102.0, // Not lower than 100.0!
            p3Index: 15,
            p4Price: 116.0,
            p4Index: 20,
            currentPrice: 100.0,
            atr: 2.0,
            isBullishStructure: true
        )
        assert(nonSweepResult.type == .none, "Expected none, got \(nonSweepResult.type)")
        print("  ✅ [PASS] Pola tanpa sapuan likuiditas (Head gagal sweep) ditolak (.none)")

        // Test 4: Failed Quasimodo - BOS did not break previous structure
        print("\n[TEST 4: REJECTED PATTERN (BOS FAILED TO BREAK HIGH 1)]")
        let nonBOSResult = engine.evaluatePattern(
            p1Price: 100.0,
            p1Index: 5,
            p2Price: 110.0,
            p2Index: 10,
            p3Price: 94.0,
            p3Index: 15,
            p4Price: 108.0, // Failed to exceed 110.0!
            p4Index: 20,
            currentPrice: 100.0,
            atr: 2.0,
            isBullishStructure: true
        )
        assert(nonBOSResult.type == .none, "Expected none, got \(nonBOSResult.type)")
        print("  ✅ [PASS] Pola tanpa Break of Structure ditolak (.none)")

        // Test 5: End-to-End Synthetic Klines Scan
        print("\n[TEST 5: END-TO-END SCAN ON SYNTHETIC KLINES]")
        func makeKline(high: Double, low: Double, close: Double, index: Int) -> AstronacciKline {
            return AstronacciKline(
                open: (high + low) / 2.0,
                high: high,
                low: low,
                close: close,
                volume: 1000.0,
                timestamp: Int64(1700000000 + index * 900),
                isClosed: true
            )
        }

        var klines: [AstronacciKline] = []
        for i in 0..<30 {
            klines.append(makeKline(high: 105, low: 100, close: 102, index: i))
        }
        // Inject Bullish QM pivots:
        // Index 5: Low 1 (LS) = 96.0
        klines[5] = makeKline(high: 98, low: 96.0, close: 97, index: 5)
        // Index 10: High 1 = 112.0
        klines[10] = makeKline(high: 112.0, low: 108, close: 110, index: 10)
        // Index 16: Head (Low 2) = 90.0 (< 96.0)
        klines[16] = makeKline(high: 93, low: 90.0, close: 91, index: 16)
        // Index 22: BOS (High 2) = 118.0 (> 112.0)
        klines[22] = makeKline(high: 118.0, low: 114, close: 116, index: 22)

        let e2eResult = engine.detectQuasimodo(klines: klines, currentPrice: 96.5, atr: 2.5)
        print("  Detected QM type: \(e2eResult.type.rawValue)")
        assert(e2eResult.type == .bullish, "Expected bullish QM from synthetic series, got \(e2eResult.type)")
        print("  ✅ [PASS] End-to-end kline scan mendeteksi Quasimodo Bullish secara deterministik")

        print("\n=================================================================")
        print("🏁 SELURUH UJI TDD ASTRONACCI QUASIMODO ENGINE LOLOS 100%!")
        print("=================================================================")
    }
}
