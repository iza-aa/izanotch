//
//  test_accounting_regression.swift
//  Unit Test Suite to Verify Position Lifecycle Accounting & Realized PnL Persistence
//

import Foundation

@main
struct AccountingRegressionTest {
    static var passed = 0
    static var total = 0

    static func assertTest(_ cond: Bool, _ name: String, details: String = "") {
        total += 1
        if cond {
            passed += 1
            print("  ✅ [PASS] \(name)")
        } else {
            print("  ❌ [FAIL] \(name) — \(details)")
        }
    }

    struct PositionTracker {
        var tradeId: String
        var dir: String
        var entry: Double
        var sl: Double
        var initialSl: Double
        var tp1: Double
        var tp2: Double
        var totalSize: Double
        var remainingSize: Double
        var stage2: Bool
        var held: Int
        var accruedGrossPnl: Double
        var accruedFeePaid: Double
        var mfePrice: Double
        var lastFundingTimestampMs: Int64

        var isFinished: Bool = false
        var finalGrossPnl: Double = 0.0
        var finalFeePaid: Double = 0.0
        var exitReason: String = ""
        var exitPrice: Double = 0.0

        mutating func updateBar(
            high: Double,
            low: Double,
            close: Double,
            timestamp: Int64,
            entryFeeRate: Double = 0.0005,
            tpExitFeeRate: Double = 0.0005,
            slExitFeeRate: Double = 0.0005,
            slippageRate: Double = 0.0005,
            maxBars: Int = 72
        ) {
            guard !isFinished else { return }
            held += 1

            // 1. Track MFE
            if dir == "LONG" {
                if high > mfePrice { mfePrice = high }
            } else {
                if low < mfePrice { mfePrice = low }
            }

            // 2. Funding Rate Deduction (every 8 hours: 00:00, 08:00, 16:00 UTC)
            let currentFundingBucket = timestamp / (8 * 3600 * 1000)
            let lastFundingBucket = lastFundingTimestampMs / (8 * 3600 * 1000)
            if currentFundingBucket > lastFundingBucket {
                let fundingRate = 0.0001 // 0.01% conservative
                let fundingCost = entry * remainingSize * fundingRate
                accruedFeePaid += fundingCost
                lastFundingTimestampMs = timestamp
            }

            // 3. Check Exits
            if held >= maxBars {
                exitPrice = close
                let diff = dir == "LONG" ? (exitPrice - entry) : (entry - exitPrice)
                let partialGross = diff * remainingSize
                let exitFee = exitPrice * remainingSize * slExitFeeRate
                finalGrossPnl = accruedGrossPnl + partialGross
                finalFeePaid = accruedFeePaid + exitFee
                exitReason = "MAX_HOLD_EXPIRED"
                isFinished = true
                return
            }

            if !stage2 {
                // Stage 1: Waiting for TP1 or SL
                if dir == "LONG" {
                    if low <= sl {
                        exitPrice = sl * (1.0 - slippageRate)
                        finalGrossPnl = (exitPrice - entry) * totalSize
                        finalFeePaid = accruedFeePaid + (entry * totalSize * entryFeeRate) + (exitPrice * totalSize * slExitFeeRate)
                        exitReason = "STOP_LOSS"
                        isFinished = true
                    } else if high >= tp1 {
                        let half = totalSize * 0.5
                        exitPrice = tp1
                        let partialGross = (exitPrice - entry) * half
                        let partialFee = (entry * half * entryFeeRate) + (exitPrice * half * tpExitFeeRate)
                        accruedGrossPnl += partialGross
                        accruedFeePaid += partialFee
                        remainingSize -= half
                        sl = entry // Move to BEP
                        stage2 = true
                    }
                } else {
                    if high >= sl {
                        exitPrice = sl * (1.0 + slippageRate)
                        finalGrossPnl = (entry - exitPrice) * totalSize
                        finalFeePaid = accruedFeePaid + (entry * totalSize * entryFeeRate) + (exitPrice * totalSize * slExitFeeRate)
                        exitReason = "STOP_LOSS"
                        isFinished = true
                    } else if low <= tp1 {
                        let half = totalSize * 0.5
                        exitPrice = tp1
                        let partialGross = (entry - exitPrice) * half
                        let partialFee = (entry * half * entryFeeRate) + (exitPrice * half * tpExitFeeRate)
                        accruedGrossPnl += partialGross
                        accruedFeePaid += partialFee
                        remainingSize -= half
                        sl = entry // Move to BEP
                        stage2 = true
                    }
                }
            } else {
                // Stage 2: Sisa 50% waiting for TP2 or BEP
                let half = remainingSize
                if dir == "LONG" {
                    if low <= sl {
                        exitPrice = sl
                        let exitFee = exitPrice * half * tpExitFeeRate
                        finalGrossPnl = accruedGrossPnl
                        finalFeePaid = accruedFeePaid + exitFee
                        exitReason = "TP1_THEN_BEP"
                        isFinished = true
                    } else if high >= tp2 {
                        exitPrice = tp2
                        let partialGross = (exitPrice - entry) * half
                        let exitFee = exitPrice * half * tpExitFeeRate
                        finalGrossPnl = accruedGrossPnl + partialGross
                        finalFeePaid = accruedFeePaid + exitFee
                        exitReason = "FULL_TP2"
                        isFinished = true
                    }
                } else {
                    if high >= sl {
                        exitPrice = sl
                        let exitFee = exitPrice * half * tpExitFeeRate
                        finalGrossPnl = accruedGrossPnl
                        finalFeePaid = accruedFeePaid + exitFee
                        exitReason = "TP1_THEN_BEP"
                        isFinished = true
                    } else if low <= tp2 {
                        exitPrice = tp2
                        let partialGross = (entry - exitPrice) * half
                        let exitFee = exitPrice * half * tpExitFeeRate
                        finalGrossPnl = accruedGrossPnl + partialGross
                        finalFeePaid = accruedFeePaid + exitFee
                        exitReason = "FULL_TP2"
                        isFinished = true
                    }
                }
            }
        }
    }

    static func main() {
        print("=================================================================")
        print("🧪 UJI REGRESI AKUNTANSI POSISI & RETENSI REALIZED PNL (LANGKAH 0)")
        print("=================================================================")

        // Skenario 1: LONG Entry 65,000, SL 64,500, TP1 66,000, TP2 67,000, Size 1.0 BTC
        // Bar 1: Gerak naik ke 66,200 -> Kena TP1 (50% closed at +$1,000/BTC -> +$500 gross)
        // Bar 2: Gerak turun ke 64,900 -> Kena BEP (SL di 65,000)
        // Expected: finalGrossPnl = +$500.00, exitReason = TP1_THEN_BEP
        var p1 = PositionTracker(
            tradeId: "TEST_TP1_BEP",
            dir: "LONG",
            entry: 65000.0,
            sl: 64500.0,
            initialSl: 64500.0,
            tp1: 66000.0,
            tp2: 67000.0,
            totalSize: 1.0,
            remainingSize: 1.0,
            stage2: false,
            held: 0,
            accruedGrossPnl: 0.0,
            accruedFeePaid: 0.0,
            mfePrice: 65000.0,
            lastFundingTimestampMs: 1785542400000
        )

        // Bar 1: Kena TP1
        p1.updateBar(high: 66200, low: 65000, close: 66100, timestamp: 1785542700000)
        assertTest(p1.stage2, "Bar 1: Posisi bertransisi ke stage2 setelah menyentuh TP1")
        assertTest(p1.remainingSize == 0.5, "Bar 1: Remaining size berkurang menjadi 0.5 BTC")
        assertTest(p1.accruedGrossPnl == 500.0, "Bar 1: accruedGrossPnl mengunci realized profit +$500.00", details: "Nilai: \(p1.accruedGrossPnl)")
        assertTest(p1.sl == 65000.0, "Bar 1: SL digeser ke level BEP (65,000)")

        // Bar 2: Kena BEP
        p1.updateBar(high: 65500, low: 64900, close: 64950, timestamp: 1785543000000)
        assertTest(p1.isFinished, "Bar 2: Posisi selesai saat tersentuh BEP")
        assertTest(p1.exitReason == "TP1_THEN_BEP", "Bar 2: Exit reason adalah TP1_THEN_BEP")
        assertTest(p1.finalGrossPnl == 500.0, "Bar 2: finalGrossPnl MEMPERTAHANKAN profit +$500.00 (tidak reset ke 0!)", details: "Nilai: \(p1.finalGrossPnl)")
        assertTest(p1.mfePrice == 66200.0, "Bar 2: MFE terekam akurat di level tertinggi 66,200")

        // Skenario 2: LONG Entry 65,000, TP1 kena di Bar 1, lalu bertahan sampai Max Hold Expired di close 65,800
        // Expected: finalGrossPnl = +$500 (TP1) + ($55,800 - $65,000)*0.5 = $500 + $400 = +$900.00
        var p2 = PositionTracker(
            tradeId: "TEST_TP1_EXPIRED",
            dir: "LONG",
            entry: 65000.0,
            sl: 64500.0,
            initialSl: 64500.0,
            tp1: 66000.0,
            tp2: 67000.0,
            totalSize: 1.0,
            remainingSize: 1.0,
            stage2: false,
            held: 71,
            accruedGrossPnl: 0.0,
            accruedFeePaid: 0.0,
            mfePrice: 65000.0,
            lastFundingTimestampMs: 1785542400000
        )
        // Set stage 2 directly for bar 71
        p2.accruedGrossPnl = 500.0
        p2.remainingSize = 0.5
        p2.stage2 = true

        p2.updateBar(high: 65900, low: 65700, close: 65800, timestamp: 1785543300000, maxBars: 72)
        assertTest(p2.isFinished, "Posisi selesai karena batas Max Bars (72 bar)")
        assertTest(p2.exitReason == "MAX_HOLD_EXPIRED", "Exit reason adalah MAX_HOLD_EXPIRED")
        assertTest(p2.finalGrossPnl == 900.0, "finalGrossPnl mengakumulasi TP1 ($500) + sisa ($400) = $900.00", details: "Nilai: \(p2.finalGrossPnl)")

        // Skenario 3: Funding Rate Calculation saat melintasi batas 8 jam
        var p3 = PositionTracker(
            tradeId: "TEST_FUNDING",
            dir: "LONG",
            entry: 65000.0,
            sl: 64500.0,
            initialSl: 64500.0,
            tp1: 66000.0,
            tp2: 67000.0,
            totalSize: 1.0,
            remainingSize: 1.0,
            stage2: false,
            held: 0,
            accruedGrossPnl: 0.0,
            accruedFeePaid: 0.0,
            mfePrice: 65000.0,
            lastFundingTimestampMs: 1785542399000 // Tepat sebelum 00:00 UTC
        )
        // Bar berikutnya melintasi 00:00:00 UTC
        p3.updateBar(high: 65100, low: 64900, close: 65050, timestamp: 1785542401000)
        let expectedFunding = 65000.0 * 1.0 * 0.0001 // $6.50
        assertTest(abs(p3.accruedFeePaid - expectedFunding) < 1e-4, "Funding fee 0.01% ($6.50) berhasil didebet saat melintasi batas 8 jam", details: "Nilai fee: \(p3.accruedFeePaid)")

        print("\nHASIL TEST REGRESI AKUNTANSI: \(passed)/\(total) PASSED\n")
        exit(passed == total ? 0 : 1)
    }
}
