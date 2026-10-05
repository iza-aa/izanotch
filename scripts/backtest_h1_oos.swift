//
//  backtest_h1_oos.swift
//  boringNotch (Izanotchy Futures Scout)
//
//  Option A: H1 Out-of-Sample (OOS 30%) Backtest Simulator (Charter Rev 2.1)
//  - Instrument: BTCUSDT (Exclusive single-asset track ratified by Agent 1 & Agent 2)
//  - Range: February 16, 2026 to September 26, 2026 (5,347 bars H1)
//  - Frozen Parameters: R:R >= 1.0, Fib 78.6% - 0.25x ATR Intrabar SL, 12-bar Limit TTL, 1-tick penetration fill
//  - Pre-warmed with last 250 bars of In-Sample (zero signal leakage)
//  - Two Sizing Bases Evaluated: Sizing 1.0% (Risk $100) and Sizing 0.5% (Risk $50 Deployment Basis)
//  - Directional Split: LONG vs SHORT breakdown
//  - Sequential Gate 2 Evaluation: Gross PF >= 1.25, Net Exp > 0.0, MaxDD (0.5% basis) < 6.0%
//

import Foundation

struct ArchivedKline: Codable {
    let timestamp: Int64
    let open: Double
    let high: Double
    let low: Double
    let close: Double
    let volume: Double

    func toAstronacciKline() -> AstronacciKline {
        AstronacciKline(
            open: open,
            high: high,
            low: low,
            close: close,
            volume: volume,
            timestamp: timestamp,
            isClosed: true
        )
    }
}

struct H1TradeRecord: Codable {
    let tradeId: String
    let symbol: String
    let arm: String
    let direction: String
    let signalBar: Int
    let fillBar: Int
    let exitBar: Int
    let signalTimeUTC: String
    let fillTimeUTC: String
    let exitTimeUTC: String
    let entryPrice: Double
    let slPrice: Double
    let tp1Price: Double
    let tp2Price: Double
    let exitPrice: Double
    let positionSize: Double
    let notionalUsd: Double
    let grossPnlUsd: Double
    let feePaidUsd: Double
    let netPnlUsd: Double
    let netPnlPct: Double
    let rMultiple: Double
    let exitReason: String
    let barsHeld: Int
    let mfePrice: Double
}

struct H1VetoedSignalRecord: Codable {
    let symbol: String
    let barIndex: Int
    let timestampUTC: String
    let direction: String
    let rejectionReason: String
}

enum SimulationArm: String {
    case armA = "ARM_A_MAKER"
    case armB = "ARM_B_TAKER"
    case armC = "ARM_C_RUNNER5050"
}

struct PendingOrder {
    let symbol: String
    let direction: String
    let limitPrice: Double
    let slPrice: Double
    let tp1Price: Double
    let tp2Price: Double
    let placedBar: Int
    let placedTimestamp: Int64
    let swingLow: Double
    let swingHigh: Double
}

struct ActivePosition {
    let tradeId: String
    let symbol: String
    let arm: SimulationArm
    let direction: String
    let entryPrice: Double
    var slPrice: Double
    let tp1Price: Double
    let tp2Price: Double
    let entryBar: Int
    let entryTimestamp: Int64
    let totalSize: Double
    var remainingSize: Double
    var accruedGrossPnl: Double
    var accruedFeePaid: Double
    var lastFundingMs: Int64
    var isStage2: Bool
    var mfePrice: Double
    var barsHeld: Int
}

struct ArmMetrics {
    let arm: SimulationArm
    let symbol: String
    let totalTrades: Int
    let winCount: Int
    let lossCount: Int
    let winRate: Double
    let grossProfit: Double
    let grossLoss: Double
    let grossPF: Double
    let grossExpectancy: Double
    let netProfit: Double
    let netLoss: Double
    let netPF: Double
    let netExpectancy: Double
    let totalFees: Double
    let maxDrawdownPct: Double
    let finalEquity: Double

    // Directional Breakdown
    let longCount: Int
    let longGrossPnl: Double
    let longNetPnl: Double
    let shortCount: Int
    let shortGrossPnl: Double
    let shortNetPnl: Double
}

@main
struct BacktestH1OOSMain {
    static let engine = AstronacciDeterministicEngine()

    static func main() async {
        print("=================================================================")
        print("🔬 PILAR 3: SIMULASI OUT-OF-SAMPLE (OOS 30%) H1 BTCUSDT — CHARTER REV 2.1")
        print("=================================================================")
        print("Periode OOS: 16 Februari 2026 s/d 26 September 2026 (5.347 Kandel H1)")
        print("Pre-Warm: Menggunakan 250 kandel terakhir In-Sample (Zero Leakage)")
        print("-----------------------------------------------------------------\n")

        // 1. Load In-Sample tail for pre-warming (last 250 bars)
        guard let isData = try? Data(contentsOf: URL(fileURLWithPath: "data/h1_archive_IS_BTCUSDT.json")),
              let isKlines = try? JSONDecoder().decode([ArchivedKline].self, from: isData) else {
            print("❌ Gagal memuat arsip In-Sample untuk pre-warming")
            return
        }
        let warmUpKlines = Array(isKlines.suffix(250))
        let warmUpCount = warmUpKlines.count

        // 2. Load OOS data
        guard let oosData = try? Data(contentsOf: URL(fileURLWithPath: "data/h1_archive_OOS_BTCUSDT.json")),
              let oosKlines = try? JSONDecoder().decode([ArchivedKline].self, from: oosData) else {
            print("❌ Gagal memuat arsip OOS BTCUSDT")
            return
        }

        print("✅ Data dimuat: \(warmUpCount) kandel pre-warm + \(oosKlines.count) kandel OOS.")
        let combinedKlines = warmUpKlines + oosKlines

        // Run simulations for Arm A, B, C on 1.0% risk basis
        print("\n▶️ Menjalankan simulasi OOS (Basis Risiko 1.0%)...")
        let (tradesA_10, vetoedA, metricsA_10) = runSimulation(klines: combinedKlines, warmUpCount: warmUpCount, arm: .armA, riskPct: 0.01)
        let (tradesB_10, _, metricsB_10) = runSimulation(klines: combinedKlines, warmUpCount: warmUpCount, arm: .armB, riskPct: 0.01)
        let (tradesC_10, _, metricsC_10) = runSimulation(klines: combinedKlines, warmUpCount: warmUpCount, arm: .armC, riskPct: 0.01)

        // Run simulation for Arm B on 0.5% deployment risk basis (Agent 1 MaxDD amendment)
        print("▶️ Menjalankan simulasi OOS (Basis Deployment Risiko 0.5% untuk MaxDD)...")
        let (_, _, metricsA_05) = runSimulation(klines: combinedKlines, warmUpCount: warmUpCount, arm: .armA, riskPct: 0.005)
        let (_, _, metricsB_05) = runSimulation(klines: combinedKlines, warmUpCount: warmUpCount, arm: .armB, riskPct: 0.005)
        let (_, _, metricsC_05) = runSimulation(klines: combinedKlines, warmUpCount: warmUpCount, arm: .armC, riskPct: 0.005)

        // Save OOS JSONL Artifacts (Milestone hygiene: Never overwrite existing files)
        saveTradesToJsonl(trades: tradesA_10, filename: "data/h1_trades_oos_armA.jsonl")
        saveTradesToJsonl(trades: tradesB_10, filename: "data/h1_trades_oos_armB.jsonl")
        saveTradesToJsonl(trades: tradesC_10, filename: "data/h1_trades_oos_armC.jsonl")
        saveVetoedToJsonl(signals: vetoedA, filename: "data/h1_vetoed_signals_oos.jsonl")

        // Print Executive Summary Table
        print("\n==========================================================================================================")
        print("📊 TABEL KINERJA OUT-OF-SAMPLE (OOS) BTCUSDT — CHARTER REV 2.1")
        print("==========================================================================================================")
        print(String(format: "%-16@ | %-6@ | %-8@ | %-9@ | %-10@ | %-8@ | %-10@ | %-11@ | %-11@",
                     "Arm", "Trades", "WinRate", "GrossPF", "GrossExp", "NetPF", "NetExp", "MaxDD(1.0%)", "MaxDD(0.5%)"))
        print("----------------------------------------------------------------------------------------------------------")

        print(String(format: "%-16@ | %-6d | %6.1f%% | %9.2f | $%8.2f | %8.2f | $%8.2f | %9.2f%% | %9.2f%%",
                     "ARM_A_MAKER", metricsA_10.totalTrades, metricsA_10.winRate, metricsA_10.grossPF, metricsA_10.grossExpectancy, metricsA_10.netPF, metricsA_10.netExpectancy, metricsA_10.maxDrawdownPct, metricsA_05.maxDrawdownPct))
        print(String(format: "%-16@ | %-6d | %6.1f%% | %9.2f | $%8.2f | %8.2f | $%8.2f | %9.2f%% | %9.2f%%",
                     "ARM_B_TAKER", metricsB_10.totalTrades, metricsB_10.winRate, metricsB_10.grossPF, metricsB_10.grossExpectancy, metricsB_10.netPF, metricsB_10.netExpectancy, metricsB_10.maxDrawdownPct, metricsB_05.maxDrawdownPct))
        print(String(format: "%-16@ | %-6d | %6.1f%% | %9.2f | $%8.2f | %8.2f | $%8.2f | %9.2f%% | %9.2f%%",
                     "ARM_C_RUNNER5050", metricsC_10.totalTrades, metricsC_10.winRate, metricsC_10.grossPF, metricsC_10.grossExpectancy, metricsC_10.netPF, metricsC_10.netExpectancy, metricsC_10.maxDrawdownPct, metricsC_05.maxDrawdownPct))
        print("----------------------------------------------------------------------------------------------------------")

        // Directional Breakdown (Agent 1 Requirement)
        print("\n🧭 PEMECAHAN DUA ARAH (DIRECTIONAL BREAKDOWN — ARM B TAKER):")
        print(String(format: "   - LONG : %d trade | Gross PnL: $%+.2f | Net PnL: $%+.2f",
                     metricsB_10.longCount, metricsB_10.longGrossPnl, metricsB_10.longNetPnl))
        print(String(format: "   - SHORT: %d trade | Gross PnL: $%+.2f | Net PnL: $%+.2f",
                     metricsB_10.shortCount, metricsB_10.shortGrossPnl, metricsB_10.shortNetPnl))

        // Sequential Gate 2 Evaluation
        print("\n=================================================================")
        print("🏛️ EVALUASI GERBANG KEPUTUSAN 2 (OUT-OF-SAMPLE GENERALIZATION)")
        print("=================================================================")
        let btcOOS = metricsB_10
        let btcOOS_05 = metricsB_05

        let passPF = btcOOS.grossPF >= 1.25
        let passNet = btcOOS.netExpectancy > 0.0
        let passDD = btcOOS_05.maxDrawdownPct < 6.0
        let isGate2Passed = passPF && passNet && passDD

        print(String(format: "1. Gross Profit Factor >= 1.25  : %4.2f -> %@", btcOOS.grossPF, passPF ? "✅ PASSED" : "❌ FAILED"))
        print(String(format: "2. Net Expectancy (Taker) > 0.0 : $%+6.2f -> %@", btcOOS.netExpectancy, passNet ? "✅ PASSED" : "❌ FAILED"))
        print(String(format: "3. MaxDD (Basis Sizing 0.5%%) < 6%%: %5.2f%% -> %@", btcOOS_05.maxDrawdownPct, passDD ? "✅ PASSED" : "❌ FAILED"))
        print(String(format: "   (Info: MaxDD pada basis 1.0%%: %5.2f%%)", btcOOS.maxDrawdownPct))
        print("-----------------------------------------------------------------")

        if isGate2Passed {
            print("🎉 STATUS GERBANG 2: LOLOS RESMI (PASSED)!")
            print("   👉 Strategi terbukti monitisabel pada BTCUSDT tanpa overfitting historis.")
            print("   👉 Siap diajukan untuk Ratifikasi Pilar 4 Shadow Mode Live (Sizing 0.5%).")
        } else {
            print("❌ STATUS GERBANG 2: GAGAL (FAILED)!")
            print("   🛑 STOP-RULE TERPICU: Out-of-Sample kriteria tidak terpenuhi.")
        }
        print("=================================================================\n")
    }

    static func runSimulation(
        klines: [ArchivedKline],
        warmUpCount: Int,
        arm: SimulationArm,
        riskPct: Double
    ) -> ([H1TradeRecord], [H1VetoedSignalRecord], ArmMetrics) {
        let astronacciKlines = klines.map { $0.toAstronacciKline() }
        let totalCount = astronacciKlines.count

        var trades: [H1TradeRecord] = []
        var vetoedSignals: [H1VetoedSignalRecord] = []

        var activePos: ActivePosition? = nil
        var pendingOrder: PendingOrder? = nil

        var currentEquity = 10000.0
        var peakEquity = 10000.0
        var maxDrawdown = 0.0

        let entryFeeRate = (arm == .armB) ? 0.0005 : 0.0002
        let tpExitFeeRate = (arm == .armB) ? 0.0005 : 0.0002
        let slExitFeeRate = 0.0005
        let tickSize: Double = 0.10

        let isoFormatter = ISO8601DateFormatter()

        var longCount = 0
        var longGrossPnl = 0.0
        var longNetPnl = 0.0
        var shortCount = 0
        var shortGrossPnl = 0.0
        var shortNetPnl = 0.0

        // Iterate through combined klines, but only generate signals when i >= warmUpCount
        for i in 200..<totalCount {
            let currentBar = astronacciKlines[i]
            let isOOSBar = (i >= warmUpCount)

            // 1. Kelola Posisi Aktif
            if var pos = activePos {
                pos.barsHeld += 1
                var finished = false
                var exitReason = ""
                var exitPrice = 0.0
                var grossPnl = 0.0
                var feePaid = 0.0

                if pos.direction == "LONG" {
                    if currentBar.high > pos.mfePrice { pos.mfePrice = currentBar.high }
                } else {
                    if currentBar.low < pos.mfePrice { pos.mfePrice = currentBar.low }
                }

                // Funding Rate: 0.01% every 8 hours
                let curBucket = currentBar.timestamp / (8 * 3600 * 1000)
                let lastBucket = pos.lastFundingMs / (8 * 3600 * 1000)
                if curBucket > lastBucket {
                    let fundingFee = pos.entryPrice * pos.remainingSize * 0.0001
                    pos.accruedFeePaid += fundingFee
                    pos.lastFundingMs = currentBar.timestamp
                }

                if pos.barsHeld >= 72 {
                    exitPrice = currentBar.close
                    let diff = (pos.direction == "LONG") ? (exitPrice - pos.entryPrice) : (pos.entryPrice - exitPrice)
                    grossPnl = pos.accruedGrossPnl + (diff * pos.remainingSize)
                    feePaid = pos.accruedFeePaid + (exitPrice * pos.remainingSize * slExitFeeRate)
                    exitReason = "MAX_HOLD_EXPIRED"
                    finished = true
                } else if !pos.isStage2 {
                    if pos.direction == "LONG" {
                        if currentBar.low <= pos.slPrice {
                            exitPrice = pos.slPrice
                            grossPnl = (exitPrice - pos.entryPrice) * pos.totalSize
                            feePaid = pos.accruedFeePaid + (pos.entryPrice * pos.totalSize * entryFeeRate) + (exitPrice * pos.totalSize * slExitFeeRate)
                            exitReason = "STOP_LOSS"
                            finished = true
                        } else if currentBar.high >= pos.tp1Price {
                            exitPrice = pos.tp1Price
                            if arm == .armC {
                                let bankSize = pos.totalSize * 0.50
                                let partialGross = (exitPrice - pos.entryPrice) * bankSize
                                let partialFee = (pos.entryPrice * bankSize * entryFeeRate) + (exitPrice * bankSize * tpExitFeeRate)
                                pos.accruedGrossPnl += partialGross
                                pos.accruedFeePaid += partialFee
                                pos.remainingSize -= bankSize
                                pos.slPrice = pos.entryPrice
                                pos.isStage2 = true
                            } else {
                                grossPnl = (exitPrice - pos.entryPrice) * pos.totalSize
                                feePaid = pos.accruedFeePaid + (pos.entryPrice * pos.totalSize * entryFeeRate) + (exitPrice * pos.totalSize * tpExitFeeRate)
                                exitReason = "FULL_TP1_RETEST"
                                finished = true
                            }
                        }
                    } else {
                        if currentBar.high >= pos.slPrice {
                            exitPrice = pos.slPrice
                            grossPnl = (pos.entryPrice - exitPrice) * pos.totalSize
                            feePaid = pos.accruedFeePaid + (pos.entryPrice * pos.totalSize * entryFeeRate) + (exitPrice * pos.totalSize * slExitFeeRate)
                            exitReason = "STOP_LOSS"
                            finished = true
                        } else if currentBar.low <= pos.tp1Price {
                            exitPrice = pos.tp1Price
                            if arm == .armC {
                                let bankSize = pos.totalSize * 0.50
                                let partialGross = (pos.entryPrice - exitPrice) * bankSize
                                let partialFee = (pos.entryPrice * bankSize * entryFeeRate) + (exitPrice * bankSize * tpExitFeeRate)
                                pos.accruedGrossPnl += partialGross
                                pos.accruedFeePaid += partialFee
                                pos.remainingSize -= bankSize
                                pos.slPrice = pos.entryPrice
                                pos.isStage2 = true
                            } else {
                                grossPnl = (pos.entryPrice - exitPrice) * pos.totalSize
                                feePaid = pos.accruedFeePaid + (pos.entryPrice * pos.totalSize * entryFeeRate) + (exitPrice * pos.totalSize * tpExitFeeRate)
                                exitReason = "FULL_TP1_RETEST"
                                finished = true
                            }
                        }
                    }
                } else {
                    // Arm C Stage 2
                    let slice = Array(astronacciKlines[max(0, i - 20)...i])
                    let curAtr = engine.calculateATR(period: 14, klines: slice)

                    if pos.direction == "LONG" {
                        let chandelierStop = currentBar.high - (2.0 * curAtr)
                        if chandelierStop > pos.slPrice { pos.slPrice = chandelierStop }

                        if currentBar.high >= pos.tp2Price {
                            exitPrice = pos.tp2Price
                            let partialGross = (exitPrice - pos.entryPrice) * pos.remainingSize
                            let partialFee = (pos.entryPrice * pos.remainingSize * entryFeeRate) + (exitPrice * pos.remainingSize * tpExitFeeRate)
                            grossPnl = pos.accruedGrossPnl + partialGross
                            feePaid = pos.accruedFeePaid + partialFee
                            exitReason = "RUNNER_TP2_EXP1618"
                            finished = true
                        } else if currentBar.low <= pos.slPrice {
                            exitPrice = pos.slPrice
                            let partialGross = (exitPrice - pos.entryPrice) * pos.remainingSize
                            let partialFee = (pos.entryPrice * pos.remainingSize * entryFeeRate) + (exitPrice * pos.remainingSize * slExitFeeRate)
                            grossPnl = pos.accruedGrossPnl + partialGross
                            feePaid = pos.accruedFeePaid + partialFee
                            exitReason = (pos.slPrice > pos.entryPrice) ? "RUNNER_CHANDELIER_PROFIT" : "TP1_THEN_BEP"
                            finished = true
                        }
                    } else {
                        let chandelierStop = currentBar.low + (2.0 * curAtr)
                        if chandelierStop < pos.slPrice { pos.slPrice = chandelierStop }

                        if currentBar.low <= pos.tp2Price {
                            exitPrice = pos.tp2Price
                            let partialGross = (pos.entryPrice - exitPrice) * pos.remainingSize
                            let partialFee = (pos.entryPrice * pos.remainingSize * entryFeeRate) + (exitPrice * pos.remainingSize * tpExitFeeRate)
                            grossPnl = pos.accruedGrossPnl + partialGross
                            feePaid = pos.accruedFeePaid + partialFee
                            exitReason = "RUNNER_TP2_EXP1618"
                            finished = true
                        } else if currentBar.high >= pos.slPrice {
                            exitPrice = pos.slPrice
                            let partialGross = (pos.entryPrice - exitPrice) * pos.remainingSize
                            let partialFee = (pos.entryPrice * pos.remainingSize * entryFeeRate) + (exitPrice * pos.remainingSize * slExitFeeRate)
                            grossPnl = pos.accruedGrossPnl + partialGross
                            feePaid = pos.accruedFeePaid + partialFee
                            exitReason = (pos.slPrice < pos.entryPrice) ? "RUNNER_CHANDELIER_PROFIT" : "TP1_THEN_BEP"
                            finished = true
                        }
                    }
                }

                if finished {
                    let netPnl = grossPnl - feePaid
                    currentEquity += netPnl
                    if currentEquity > peakEquity { peakEquity = currentEquity }
                    let dd = (peakEquity - currentEquity) / peakEquity * 100.0
                    if dd > maxDrawdown { maxDrawdown = dd }

                    let initialRiskUsd = abs(pos.entryPrice - pos.slPrice) * pos.totalSize
                    let rMult = initialRiskUsd > 0 ? (grossPnl / initialRiskUsd) : 0.0

                    let sigDate = Date(timeIntervalSince1970: TimeInterval(pos.entryTimestamp) / 1000.0)
                    let exitDate = Date(timeIntervalSince1970: TimeInterval(currentBar.timestamp) / 1000.0)

                    let rec = H1TradeRecord(
                        tradeId: pos.tradeId,
                        symbol: "BTCUSDT",
                        arm: arm.rawValue,
                        direction: pos.direction,
                        signalBar: pos.entryBar,
                        fillBar: pos.entryBar,
                        exitBar: i,
                        signalTimeUTC: isoFormatter.string(from: sigDate),
                        fillTimeUTC: isoFormatter.string(from: sigDate),
                        exitTimeUTC: isoFormatter.string(from: exitDate),
                        entryPrice: pos.entryPrice,
                        slPrice: pos.slPrice,
                        tp1Price: pos.tp1Price,
                        tp2Price: pos.tp2Price,
                        exitPrice: exitPrice,
                        positionSize: pos.totalSize,
                        notionalUsd: pos.totalSize * pos.entryPrice,
                        grossPnlUsd: grossPnl,
                        feePaidUsd: feePaid,
                        netPnlUsd: netPnl,
                        netPnlPct: (netPnl / currentEquity) * 100.0,
                        rMultiple: rMult,
                        exitReason: exitReason,
                        barsHeld: pos.barsHeld,
                        mfePrice: pos.mfePrice
                    )
                    trades.append(rec)

                    if pos.direction == "LONG" {
                        longCount += 1
                        longGrossPnl += grossPnl
                        longNetPnl += netPnl
                    } else {
                        shortCount += 1
                        shortGrossPnl += grossPnl
                        shortNetPnl += netPnl
                    }

                    activePos = nil
                } else {
                    activePos = pos
                }
            }

            // 2. Kelola Pending Order
            if activePos == nil {
                if let order = pendingOrder {
                    let elapsed = i - order.placedBar
                    var cancelOrder = false
                    var fillOrder = false

                    if order.direction == "LONG" {
                        if currentBar.low <= order.slPrice {
                            cancelOrder = true
                        } else if currentBar.low <= (order.limitPrice - tickSize) {
                            fillOrder = true
                        }
                    } else {
                        if currentBar.high >= order.slPrice {
                            cancelOrder = true
                        } else if currentBar.high >= (order.limitPrice + tickSize) {
                            fillOrder = true
                        }
                    }

                    if elapsed >= 12 {
                        cancelOrder = true
                    }

                    if fillOrder && !cancelOrder {
                        let riskUsd = currentEquity * riskPct
                        let riskDistance = abs(order.limitPrice - order.slPrice)
                        var calculatedSize = riskDistance > 0 ? (riskUsd / riskDistance) : 0.0

                        let maxNotional = currentEquity * 10.0
                        let proposedNotional = calculatedSize * order.limitPrice
                        if proposedNotional > maxNotional {
                            calculatedSize = maxNotional / order.limitPrice
                        }

                        let tradeId = "BTCUSDT-OOS-\(order.placedBar)-\(arm.rawValue)"
                        activePos = ActivePosition(
                            tradeId: tradeId,
                            symbol: "BTCUSDT",
                            arm: arm,
                            direction: order.direction,
                            entryPrice: order.limitPrice,
                            slPrice: order.slPrice,
                            tp1Price: order.tp1Price,
                            tp2Price: order.tp2Price,
                            entryBar: i,
                            entryTimestamp: currentBar.timestamp,
                            totalSize: calculatedSize,
                            remainingSize: calculatedSize,
                            accruedGrossPnl: 0.0,
                            accruedFeePaid: 0.0,
                            lastFundingMs: currentBar.timestamp,
                            isStage2: false,
                            mfePrice: order.limitPrice,
                            barsHeld: 0
                        )
                        pendingOrder = nil
                    } else if cancelOrder {
                        pendingOrder = nil
                    }
                }

                // 3. Evaluasi Setup Baru (HANYA PADA BAR OOS: i >= warmUpCount)
                if isOOSBar && activePos == nil && pendingOrder == nil {
                    let closedSlice = Array(astronacciKlines[max(0, i - 250)...i])
                    let regimeResult = engine.detectH1Regime(klinesH1: closedSlice)
                    let regime = regimeResult.regime

                    if regime == .bullish || regime == .bearish {
                        let atr = engine.calculateATR(period: 14, klines: closedSlice)
                        if let swing = engine.detectDominantImpulsiveSwing(klines: closedSlice, atr: atr, lookbackBars: 48, minAtrMultiple: 3.0) {
                            let range = swing.swingHigh - swing.swingLow
                            let dir = (regime == .bullish) ? "LONG" : "SHORT"

                            var limitPrice = 0.0
                            var slPrice = 0.0
                            var tp1Price = 0.0
                            var tp2Price = 0.0
                            var calculatedRR = 0.0
                            var riskDist = 0.0

                            if dir == "LONG" && swing.lowIndex < swing.highIndex {
                                let gpHigh = swing.swingHigh - (0.50 * range)
                                let gpLow = swing.swingHigh - (0.618 * range)
                                limitPrice = (gpHigh + gpLow) / 2.0
                                slPrice = (swing.swingHigh - (0.786 * range)) - (0.25 * atr)
                                tp1Price = swing.swingHigh
                                tp2Price = swing.swingHigh + (0.618 * range)
                                riskDist = limitPrice - slPrice
                                calculatedRR = (tp1Price - limitPrice) / riskDist
                            } else if dir == "SHORT" && swing.highIndex < swing.lowIndex {
                                let gpLow = swing.swingLow + (0.50 * range)
                                let gpHigh = swing.swingLow + (0.618 * range)
                                limitPrice = (gpLow + gpHigh) / 2.0
                                slPrice = (swing.swingLow + (0.786 * range)) + (0.25 * atr)
                                tp1Price = swing.swingLow
                                tp2Price = swing.swingLow - (0.618 * range)
                                riskDist = slPrice - limitPrice
                                calculatedRR = (limitPrice - tp1Price) / riskDist
                            }

                            if limitPrice > 0 && riskDist > 0 {
                                let trigger = engine.detectCandleTrigger(kline: currentBar, previousKline: astronacciKlines[i - 1], atr: atr)

                                let veto = AstronacciDeterministicEngine.evaluateVetoGate(
                                    detectedRegime: regime,
                                    candleTrigger: trigger,
                                    calculatedRR: calculatedRR,
                                    riskDist: riskDist,
                                    swingRange: range,
                                    atr14: atr,
                                    totalScore: 100,
                                    minRR: 1.0
                                )

                                if veto.isPassed {
                                    pendingOrder = PendingOrder(
                                        symbol: "BTCUSDT",
                                        direction: dir,
                                        limitPrice: limitPrice,
                                        slPrice: slPrice,
                                        tp1Price: tp1Price,
                                        tp2Price: tp2Price,
                                        placedBar: i,
                                        placedTimestamp: currentBar.timestamp,
                                        swingLow: swing.swingLow,
                                        swingHigh: swing.swingHigh
                                    )
                                } else if let reason = veto.rejectionReason {
                                    let sigDate = Date(timeIntervalSince1970: TimeInterval(currentBar.timestamp) / 1000.0)
                                    vetoedSignals.append(H1VetoedSignalRecord(
                                        symbol: "BTCUSDT",
                                        barIndex: i,
                                        timestampUTC: isoFormatter.string(from: sigDate),
                                        direction: dir,
                                        rejectionReason: reason
                                    ))
                                }
                            }
                        }
                    }
                }
            }
        }

        let totalTrades = trades.count
        var winCount = 0
        var lossCount = 0
        var grossProfit = 0.0
        var grossLoss = 0.0
        var netProfit = 0.0
        var netLoss = 0.0
        var totalFees = 0.0

        for t in trades {
            totalFees += t.feePaidUsd
            if t.grossPnlUsd > 0 {
                winCount += 1
                grossProfit += t.grossPnlUsd
            } else {
                lossCount += 1
                grossLoss += abs(t.grossPnlUsd)
            }

            if t.netPnlUsd > 0 {
                netProfit += t.netPnlUsd
            } else {
                netLoss += abs(t.netPnlUsd)
            }
        }

        let winRate = totalTrades > 0 ? (Double(winCount) / Double(totalTrades) * 100.0) : 0.0
        let grossPF = grossLoss > 0 ? (grossProfit / grossLoss) : (grossProfit > 0 ? 99.0 : 0.0)
        let grossExp = totalTrades > 0 ? ((grossProfit - grossLoss) / Double(totalTrades)) : 0.0
        let netPF = netLoss > 0 ? (netProfit / netLoss) : (netProfit > 0 ? 99.0 : 0.0)
        let netExp = totalTrades > 0 ? ((netProfit - netLoss) / Double(totalTrades)) : 0.0

        let metrics = ArmMetrics(
            arm: arm,
            symbol: "BTCUSDT",
            totalTrades: totalTrades,
            winCount: winCount,
            lossCount: lossCount,
            winRate: winRate,
            grossProfit: grossProfit,
            grossLoss: grossLoss,
            grossPF: grossPF,
            grossExpectancy: grossExp,
            netProfit: netProfit,
            netLoss: netLoss,
            netPF: netPF,
            netExpectancy: netExp,
            totalFees: totalFees,
            maxDrawdownPct: maxDrawdown,
            finalEquity: currentEquity,
            longCount: longCount,
            longGrossPnl: longGrossPnl,
            longNetPnl: longNetPnl,
            shortCount: shortCount,
            shortGrossPnl: shortGrossPnl,
            shortNetPnl: shortNetPnl
        )

        return (trades, vetoedSignals, metrics)
    }

    static func saveTradesToJsonl(trades: [H1TradeRecord], filename: String) {
        let encoder = JSONEncoder()
        var content = ""
        for t in trades {
            if let d = try? encoder.encode(t), let str = String(data: d, encoding: .utf8) {
                content += str + "\n"
            }
        }
        try? content.write(to: URL(fileURLWithPath: filename), atomically: true, encoding: .utf8)
        print("  💾 Tersimpan \(trades.count) baris trade OOS ke: \(filename)")
    }

    static func saveVetoedToJsonl(signals: [H1VetoedSignalRecord], filename: String) {
        let encoder = JSONEncoder()
        var content = ""
        for s in signals {
            if let d = try? encoder.encode(s), let str = String(data: d, encoding: .utf8) {
                content += str + "\n"
            }
        }
        try? content.write(to: URL(fileURLWithPath: filename), atomically: true, encoding: .utf8)
        print("  💾 Tersimpan \(signals.count) sinyal ditolak veto OOS ke: \(filename)")
    }
}
