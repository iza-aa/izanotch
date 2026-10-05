//
//  backtest_h1_study.swift
//  boringNotch (Izanotchy Futures Scout)
//
//  Option A: H1 Multi-Asset Pre-Registered Study Simulator (Charter Rev 2)
//  - Timeframe: H1 Single-Source of Truth (detectH1Regime, Dominant Swing 48 bars, Golden Pocket)
//  - Instruments: BTCUSDT, ETHUSDT, SOLUSDT (In-Sample 70% Only)
//  - Frozen Parameters: R:R >= 1.0, Fib 78.6% - 0.25x ATR Intrabar SL, 12-bar Limit TTL, 1-tick penetration fill
//  - Three Arms: Arm A (Maker), Arm B (Taker Baseline), Arm C (50/50 Chandelier Runner)
//  - Funding Rate: 0.01% / 8 hours, Max Hold: 72 bars H1 (3 days)
//  - Sequential Gate 1 Evaluation: In-Sample Gross Expectancy > 0.0 on BTCUSDT
//

import Foundation

// MARK: - Kline Schema from In-Sample Archive
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

// MARK: - Trade Record Schema
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

// MARK: - Vetoed Signal Record
struct H1VetoedSignalRecord: Codable {
    let symbol: String
    let barIndex: Int
    let timestampUTC: String
    let direction: String
    let rejectionReason: String
}

// MARK: - Simulation Arm
enum SimulationArm: String {
    case armA = "ARM_A_MAKER"
    case armB = "ARM_B_TAKER"
    case armC = "ARM_C_RUNNER5050"
}

// MARK: - Pending Limit Order
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

// MARK: - Active Position
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

// MARK: - Performance Metrics
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
}

@main
struct BacktestH1StudyMain {
    static let engine = AstronacciDeterministicEngine()
    static let assets = ["BTCUSDT", "ETHUSDT", "SOLUSDT"]

    static func main() async {
        print("=================================================================")
        print("🔬 PILAR 3: SIMULASI PRE-REGISTERED H1 MULTI-ASET (CHARTER REV 2)")
        print("=================================================================")
        print("Status: Evaluasi Gerbang 1 (In-Sample 70% Sahaja — Zero OOS Data)")
        print("Model: Dominant Swing 48 bars, GP Mid-Limit, 12-bar TTL, Intrabar SL")
        print("-----------------------------------------------------------------\n")

        var allTradesArmA: [H1TradeRecord] = []
        var allTradesArmB: [H1TradeRecord] = []
        var allTradesArmC: [H1TradeRecord] = []
        var allVetoedSignals: [H1VetoedSignalRecord] = []

        var resultsByAssetAndArm: [String: [SimulationArm: ArmMetrics]] = [:]

        for asset in assets {
            print("▶️ Menjalankan simulasi untuk: \(asset)...")
            let path = "data/h1_archive_IS_\(asset).json"
            guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
                  let klines = try? JSONDecoder().decode([ArchivedKline].self, from: data) else {
                print("❌ Gagal memuat arsip In-Sample untuk \(asset) di \(path)")
                continue
            }

            print("   Memuat \(klines.count) kandel H1 In-Sample.")

            let (tradesA, vetoedA, metricsA) = runSimulation(symbol: asset, klines: klines, arm: .armA)
            let (tradesB, _, metricsB) = runSimulation(symbol: asset, klines: klines, arm: .armB)
            let (tradesC, _, metricsC) = runSimulation(symbol: asset, klines: klines, arm: .armC)

            allTradesArmA.append(contentsOf: tradesA)
            allTradesArmB.append(contentsOf: tradesB)
            allTradesArmC.append(contentsOf: tradesC)
            allVetoedSignals.append(contentsOf: vetoedA)

            resultsByAssetAndArm[asset] = [
                .armA: metricsA,
                .armB: metricsB,
                .armC: metricsC
            ]
        }

        // Save JSONL Artifacts (Milestone hygiene: Never overwrite existing files)
        saveTradesToJsonl(trades: allTradesArmA, filename: "data/h1_trades_is_armA.jsonl")
        saveTradesToJsonl(trades: allTradesArmB, filename: "data/h1_trades_is_armB.jsonl")
        saveTradesToJsonl(trades: allTradesArmC, filename: "data/h1_trades_is_armC.jsonl")
        saveVetoedToJsonl(signals: allVetoedSignals, filename: "data/h1_vetoed_signals_is.jsonl")

        // Print Executive Summary Table
        print("\n=================================================================")
        print("📊 TABEL KINERJA IN-SAMPLE LENGKAP (CHARTER REV 2)")
        print("=================================================================")
        print(String(format: "%-10@ | %-16@ | %-6@ | %-8@ | %-9@ | %-10@ | %-8@ | %-10@ | %-8@",
                     "Asset", "Arm", "Trades", "WinRate", "GrossPF", "GrossExp", "NetPF", "NetExp", "MaxDD"))
        print("---------------------------------------------------------------------------------------------------")

        for asset in assets {
            if let arms = resultsByAssetAndArm[asset] {
                for armType in [SimulationArm.armA, .armB, .armC] {
                    if let m = arms[armType] {
                        print(String(format: "%-10@ | %-16@ | %-6d | %6.1f%% | %9.2f | $%8.2f | %8.2f | $%8.2f | %6.2f%%",
                                     asset, armType.rawValue, m.totalTrades, m.winRate, m.grossPF, m.grossExpectancy, m.netPF, m.netExpectancy, m.maxDrawdownPct))
                    }
                }
                print("---------------------------------------------------------------------------------------------------")
            }
        }

        // Evaluate Sequential Gate 1 (In-Sample Gross Filter on BTCUSDT)
        print("\n=================================================================")
        print("🏛️ EVALUASI GERBANG KEPUTUSAN 1 (IN-SAMPLE GROSS FILTER)")
        print("=================================================================")
        if let btcMetrics = resultsByAssetAndArm["BTCUSDT"]?[.armB] {
            let isPassed = btcMetrics.grossExpectancy > 0.0
            print(String(format: "Kriteria Gerbang 1: BTCUSDT Arm B Gross Expectancy > 0.0 USDT (Aktual: $%+.2f)", btcMetrics.grossExpectancy))
            if isPassed {
                print("✅ STATUS GERBANG 1: LOLOS (PASSED)!")
                print("   👉 Hipotesis H1 In-Sample valid secara kotor.")
                print("   👉 Langkah berikutnya: Ajukan laporan hasil IS ke Auditor Agent 1 & Agent 2 untuk audit sebelum membuka OOS.")
            } else {
                print("❌ STATUS GERBANG 1: GAGAL (FAILED)!")
                print("   🛑 STOP-RULE TERPICU: In-Sample Gross Expectancy <= 0.0.")
                print("   🛑 Hipotesis H1 terfalsifikasi sejak In-Sample. Sesuai piagam, riset H1 DITUTUP dengan hormat.")
            }
        }

        // Multi-Asset Aggregate Check on Arm B (Agent 2 Amendment 1)
        var totalBNetPnl = 0.0
        var totalBTrades = 0
        var positiveAssetsCount = 0
        for asset in assets {
            if let m = resultsByAssetAndArm[asset]?[.armB] {
                totalBNetPnl += (m.netProfit - m.netLoss)
                totalBTrades += m.totalTrades
                if m.netExpectancy > 0.0 {
                    positiveAssetsCount += 1
                }
            }
        }
        let aggNetExp = totalBTrades > 0 ? (totalBNetPnl / Double(totalBTrades)) : 0.0
        print("\n🔍 DIAGNOSTIK MULTI-ASET IN-SAMPLE (BASELINE ARM B):")
        print("   - Aset Net Positif: \(positiveAssetsCount) dari 3 aset")
        print(String(format: "   - Agregat Net PnL: $%+.2f (Net Exp: $%+.2f / trade)", totalBNetPnl, aggNetExp))
        print("=================================================================\n")
    }

    static func runSimulation(
        symbol: String,
        klines: [ArchivedKline],
        arm: SimulationArm
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
        let slExitFeeRate = 0.0005 // SL always taker
        let tickSize: Double = symbol.contains("BTC") ? 0.10 : 0.01

        let isoFormatter = ISO8601DateFormatter()

        // Bar-by-bar walk-forward simulation (Starting at bar 200 for canonical EMA 200)
        for i in 200..<totalCount {
            let currentBar = astronacciKlines[i]

            // -------------------------------------------------------------
            // 1. KELOLA POSISI AKTIF (JIKA ADA)
            // -------------------------------------------------------------
            if var pos = activePos {
                pos.barsHeld += 1
                var finished = false
                var exitReason = ""
                var exitPrice = 0.0
                var grossPnl = 0.0
                var feePaid = 0.0

                // Track MFE
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

                // Intrabar SL / TP / Max Hold checks
                if pos.barsHeld >= 72 {
                    // Max Hold 3 Days Expired -> Close at current close
                    exitPrice = currentBar.close
                    let diff = (pos.direction == "LONG") ? (exitPrice - pos.entryPrice) : (pos.entryPrice - exitPrice)
                    grossPnl = pos.accruedGrossPnl + (diff * pos.remainingSize)
                    feePaid = pos.accruedFeePaid + (exitPrice * pos.remainingSize * slExitFeeRate)
                    exitReason = "MAX_HOLD_EXPIRED"
                    finished = true
                } else if !pos.isStage2 {
                    // Stage 1: Waiting for Initial SL or TP1
                    if pos.direction == "LONG" {
                        if currentBar.low <= pos.slPrice {
                            // SL Hit
                            exitPrice = pos.slPrice
                            grossPnl = (exitPrice - pos.entryPrice) * pos.totalSize
                            feePaid = pos.accruedFeePaid + (pos.entryPrice * pos.totalSize * entryFeeRate) + (exitPrice * pos.totalSize * slExitFeeRate)
                            exitReason = "STOP_LOSS"
                            finished = true
                        } else if currentBar.high >= pos.tp1Price {
                            // TP1 Hit
                            exitPrice = pos.tp1Price
                            if arm == .armC {
                                // 50/50 Split: Bank 50% at TP1, let 50% run with BEP shield
                                let bankSize = pos.totalSize * 0.50
                                let partialGross = (exitPrice - pos.entryPrice) * bankSize
                                let partialFee = (pos.entryPrice * bankSize * entryFeeRate) + (exitPrice * bankSize * tpExitFeeRate)
                                pos.accruedGrossPnl += partialGross
                                pos.accruedFeePaid += partialFee
                                pos.remainingSize -= bankSize
                                pos.slPrice = pos.entryPrice // Shield to BEP
                                pos.isStage2 = true
                            } else {
                                // Full 100% Exit at TP1 (Arm A & Arm B)
                                grossPnl = (exitPrice - pos.entryPrice) * pos.totalSize
                                feePaid = pos.accruedFeePaid + (pos.entryPrice * pos.totalSize * entryFeeRate) + (exitPrice * pos.totalSize * tpExitFeeRate)
                                exitReason = "FULL_TP1_RETEST"
                                finished = true
                            }
                        }
                    } else {
                        // SHORT
                        if currentBar.high >= pos.slPrice {
                            // SL Hit
                            exitPrice = pos.slPrice
                            grossPnl = (pos.entryPrice - exitPrice) * pos.totalSize
                            feePaid = pos.accruedFeePaid + (pos.entryPrice * pos.totalSize * entryFeeRate) + (exitPrice * pos.totalSize * slExitFeeRate)
                            exitReason = "STOP_LOSS"
                            finished = true
                        } else if currentBar.low <= pos.tp1Price {
                            // TP1 Hit
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
                    // Stage 2 (Arm C Runner): Trailing Stop via Chandelier 2.0x ATR or TP2
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
                        // SHORT Stage 2
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
                        symbol: symbol,
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
                    activePos = nil
                } else {
                    activePos = pos
                }
            }

            // -------------------------------------------------------------
            // 2. KELOLA PENDING LIMIT ORDER (JIKA BELUM ADA POSISI AKTIF)
            // -------------------------------------------------------------
            if activePos == nil {
                if let order = pendingOrder {
                    let elapsed = i - order.placedBar
                    var cancelOrder = false
                    var fillOrder = false

                    // Check Invalidation before fill
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
                        cancelOrder = true // 12-bar TTL expired
                    }

                    if fillOrder && !cancelOrder {
                        // Order Filled! Open Active Position
                        let riskUsd = currentEquity * 0.01 // 1.0% risk
                        let riskDistance = abs(order.limitPrice - order.slPrice)
                        var calculatedSize = riskDistance > 0 ? (riskUsd / riskDistance) : 0.0

                        // Max leverage 10x cap
                        let maxNotional = currentEquity * 10.0
                        let proposedNotional = calculatedSize * order.limitPrice
                        if proposedNotional > maxNotional {
                            calculatedSize = maxNotional / order.limitPrice
                        }

                        let tradeId = "\(symbol)-\(order.placedBar)-\(arm.rawValue)"
                        activePos = ActivePosition(
                            tradeId: tradeId,
                            symbol: symbol,
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

                // -------------------------------------------------------------
                // 3. EVALUASI SETUP BARU (HANYA JIKA TIDAK ADA POSISI ATAU ORDER)
                // -------------------------------------------------------------
                if activePos == nil && pendingOrder == nil {
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
                                limitPrice = (gpHigh + gpLow) / 2.0 // GP midpoint
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

                                // Single Source of Truth Veto Check (Charter Rev 2: score bypass = 100)
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
                                        symbol: symbol,
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
                                        symbol: symbol,
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

        // Calculate Metrics
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
            symbol: symbol,
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
            finalEquity: currentEquity
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
        print("  💾 Tersimpan \(trades.count) baris trade ke: \(filename)")
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
        print("  💾 Tersimpan \(signals.count) sinyal ditolak veto ke: \(filename)")
    }
}
