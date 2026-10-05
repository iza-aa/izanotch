//
//  backtest_astronacci_6months.swift
//  boringNotch (Izanotchy Futures Scout)
//
//  Pilar 3: Verifikasi Backtest Historis 6 Bulan Opsi A Canon
//  Framework: Asst. Prof. Dr. Gema Merdeka Goeyardi (Astronacci International)
//  Amendemen 1, 2, 3, 4 Canon:
//  - Single Source of Truth untuk Gerbang Veto (evaluateVetoGate)
//  - Konfigurasi Primer: Chandelier 2.0x ATR + Maker Post-Only + Session Filter OFF
//  - Pre-Registered 50/50 Split (Bank TP1 Swing High 1.0, Runner TP2 Exp 1.618)
//  - Sweep Sensitivitas Fill-Rate (70/80/90/100%) & Breakeven Fill Rate
//  - Sensitivitas: Taker vs Maker, Session ON vs OFF, Split 50/50 vs 30/70
//  - Diagnostik Desil Skor Konfluensi
//

import Foundation

// MARK: - Raw Kline JSON Schema
struct RawHistoricalKline: Codable {
    let timestamp: Int64
    let open: Double
    let high: Double
    let low: Double
    let close: Double
    let volume: Double
}

// MARK: - Backtest Trade Record
struct BacktestTradeRecord: Codable {
    let tradeId: String
    let signalTimeUTC: String
    let fillTimeUTC: String
    let exitTimeUTC: String
    let direction: String          // LONG or SHORT
    let grade: String              // A_GRADE or B_GRADE
    let entryPrice: Double
    let stopLossPrice: Double
    let tp1Price: Double
    let tp2Price: Double
    let exitPrice: Double
    let positionSizeBtc: Double
    let notionalUsd: Double
    let grossPnlUsd: Double
    let feePaidUsd: Double
    let netPnlUsd: Double
    let netPnlPct: Double
    let rMultiple: Double
    let exitReason: String         // FULL_TP2, RUNNER_TP2, RUNNER_TRAILING_STOP, TP1_THEN_BEP, STOP_LOSS, MAX_HOLD_EXPIRED
    let barsHeld: Int
    let mfePrice: Double
    let mfeAtrRatio: Double
    let sampleType: String         // IN_SAMPLE or OUT_OF_SAMPLE
    let accountEquityAfter: Double
}

// MARK: - Counterfactual Veto Record
struct CounterfactualVetoRecord: Codable {
    let signalTimeUTC: String
    let direction: String
    let score: Int
    let rejectionReason: String
    let simulatedNetPnlUsd: Double
    let isWinner: Bool
}

// MARK: - Simulation Stage Configuration
enum AblationStage {
    case baseline                                           // 0. Baseline lama + Fix Akuntansi (Hold 24 bar)
    case stage1_dominantSwing                               // 1. Dominant Swing (>= 4.0x ATR, Lookback 48 bar) + Old TP/Hold
    case stage2a_swingHighTP                                // 2a. Dominant Swing + SL Struct + TP1 Swing High (1.0) + Hold 72 bar + Funding
    case stage2b_exp1272TP                                  // 2b. Dominant Swing + SL Struct + TP1 Exp 1.272 + Hold 72 bar + Funding
    case stage3_blendedFee                                  // 3. Best Stage 2 Sub-Ablation + Maker Fee (0.02% / SL 0.05%) + Funding
    case stage4_primary_runner5050_maker_sessionOff         // 4a. KONFIGURASI PRIMER: Chandelier 2.0x ATR + Maker + Session OFF (Amendemen 1, 2, 3)
    case stage4_variant_taker                               // 4b. SENSITIVITAS BIAYA: Chandelier 2.0x ATR + Taker + Session OFF
    case stage4_variant_sessionOn                           // 4c. SENSITIVITAS SESI: Chandelier 2.0x ATR + Maker + Session ON (12:30-16:00 UTC)
    case stage4_variant_runner3070                          // 4d. SENSITIVITAS SPLIT: 30/70 Runner + Chandelier 2.0x ATR + Maker + Session OFF
}

// MARK: - Simulation Metrics Result
struct SimulationResult {
    let stageName: String
    let totalTrades: Int
    let winCount: Int
    let lossCount: Int
    let bepCount: Int
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
    let finalEquity: Double
    let maxDrawdownPct: Double
    let fastSlRate: Double         // Persentase SL yang kena dalam <= 2 bar (5-10 menit)
    let avgBarsHeld: Double
    let targetReachabilityRate: Double // Persentase trade yang mencapai MFE >= TP1
    let medianMfeRatio: Double
    let trades: [BacktestTradeRecord]
}

// MARK: - Main Backtest Simulator
@main
struct BacktestSimulatorMain {
    static func main() {
        let runner = BacktestRunner()
        runner.executeCompleteHarness()
    }
}

final class BacktestRunner {
    let baseDir = "data/historical_klines"
    let engine = AstronacciDeterministicEngine.shared
    let initialCapital: Double = 10000.0
    let outOfSampleCutoffMs: Int64 = 1785542400000 // 1 Agustus 2026 00:00:00 UTC

    func executeCompleteHarness() {
        print("================================================================================")
        print("🏛️ IZANOTCHY FUTURES SCOUT — PILAR 3: VERIFIKASI ABLASI OPSI A & OPSI 2 (6 BULAN)")
        print("   Framework: Astronacci International Institutional Scalping Specification")
        print("   Data     : BTCUSDT Perpetual (1 April 2026 s.d. 26 September 2026)")
        print("   Mandat   : Harmonisasi R:R >= 1.0 (Single Source) + Runner 50/50 Chandelier 2xATR")
        print("================================================================================\n")

        // 1. Muat Dataset Historis
        guard let h1Raw = loadKlines(from: "\(baseDir)/btcusdt_1h_6m.json"),
              let m15Raw = loadKlines(from: "\(baseDir)/btcusdt_15m_6m.json"),
              let m5Raw = loadKlines(from: "\(baseDir)/btcusdt_5m_6m.json") else {
            print("❌ Gagal memuat berkas dataset historis di \(baseDir).")
            exit(1)
        }

        print("📦 Dataset Historis Terverifikasi:")
        print("   • H1 Bars : \(h1Raw.count) bar")
        print("   • M15 Bars: \(m15Raw.count) bar")
        print("   • M5 Bars : \(m5Raw.count) bar (Total 51.417 bar)")

        let h1Klines = h1Raw.map { AstronacciKline(open: $0.open, high: $0.high, low: $0.low, close: $0.close, volume: $0.volume, timestamp: $0.timestamp, isClosed: true) }
        let m15Klines = m15Raw.map { AstronacciKline(open: $0.open, high: $0.high, low: $0.low, close: $0.close, volume: $0.volume, timestamp: $0.timestamp, isClosed: true) }
        let m5Klines = m5Raw.map { AstronacciKline(open: $0.open, high: $0.high, low: $0.low, close: $0.close, volume: $0.volume, timestamp: $0.timestamp, isClosed: true) }

        var vetoedSignals: [CounterfactualVetoRecord] = []

        // 2. Jalankan Ablasi Bertahap (Full 6-Month Dataset)
        print("\n--------------------------------------------------------------------------------")
        print("🔬 BAGIAN A: STUDI ABLASI BERTINGKAT OPSI A & OPSI 2")
        print("--------------------------------------------------------------------------------")

        let baselineRes = runSimulation(stage: .baseline, h1: h1Klines, m15: m15Klines, m5: m5Klines) { v in
            vetoedSignals.append(v)
        }
        printAblationRow(res: baselineRes, label: "0. BASELINE (Aturan Lama + Fix Akuntansi D)")
        saveJsonl(trades: baselineRes.trades, filename: "data/FuturesScoutPaperTrades_baseline.jsonl")

        let stage1Res = runSimulation(stage: .stage1_dominantSwing, h1: h1Klines, m15: m15Klines, m5: m5Klines)
        printAblationRow(res: stage1Res, label: "1. TAHAP 1 (+ Dominant Swing >= 4.0x ATR, Lookback 48 bar)")
        saveJsonl(trades: stage1Res.trades, filename: "data/FuturesScoutPaperTrades_stage1.jsonl")

        let stage2aRes = runSimulation(stage: .stage2a_swingHighTP, h1: h1Klines, m15: m15Klines, m5: m5Klines)
        printAblationRow(res: stage2aRes, label: "2a. TAHAP 2a (+ SL Struct + TP1 Swing High 1.0 + Hold 72 bar + Funding)")
        saveJsonl(trades: stage2aRes.trades, filename: "data/FuturesScoutPaperTrades_stage2a.jsonl")

        let stage2bRes = runSimulation(stage: .stage2b_exp1272TP, h1: h1Klines, m15: m15Klines, m5: m5Klines)
        printAblationRow(res: stage2bRes, label: "2b. TAHAP 2b (+ SL Struct + TP1 Exp 1.272 + Hold 72 bar + Funding)")
        saveJsonl(trades: stage2bRes.trades, filename: "data/FuturesScoutPaperTrades_stage2b.jsonl")

        let stage3Res = runSimulation(stage: .stage3_blendedFee, h1: h1Klines, m15: m15Klines, m5: m5Klines)
        printAblationRow(res: stage3Res, label: "3. TAHAP 3 (+ Model Fee Maker 0.02% / SL 0.05% pada Tahap 2a)")
        saveJsonl(trades: stage3Res.trades, filename: "data/FuturesScoutPaperTrades_stage3.jsonl")

        // 3. Konfigurasi Primer & Sensitivitas Opsi 2 (Amendemen 1, 2, 3 Canon)
        print("\n--------------------------------------------------------------------------------")
        print("🏆 BAGIAN B: KONFIGURASI PRIMER & SENSITIVITAS OPSI 2 (RUNNER 50/50 CHANDELIER)")
        print("--------------------------------------------------------------------------------")

        // 4a. Konfigurasi Primer: Chandelier 2.0x ATR + Maker Post-Only + Session OFF
        let stage4PrimaryRes = runSimulation(stage: .stage4_primary_runner5050_maker_sessionOff, h1: h1Klines, m15: m15Klines, m5: m5Klines)
        printAblationRow(res: stage4PrimaryRes, label: "4a. KONFIGURASI PRIMER (Chandelier 2xATR + Maker 0.02% + Session OFF + Split 50/50)")
        saveJsonl(trades: stage4PrimaryRes.trades, filename: "data/FuturesScoutPaperTrades_stage4_primary.jsonl")
        saveJsonl(trades: stage4PrimaryRes.trades, filename: "data/FuturesScoutPaperTrades.jsonl") // Active Canon

        // 4b. Sensitivitas Biaya: Chandelier 2.0x ATR + Taker Fee + Session OFF
        let stage4TakerRes = runSimulation(stage: .stage4_variant_taker, h1: h1Klines, m15: m15Klines, m5: m5Klines)
        printAblationRow(res: stage4TakerRes, label: "4b. SENSITIVITAS BIAYA TAKER (Chandelier 2xATR + Taker 0.05% + Session OFF + Split 50/50)")
        saveJsonl(trades: stage4TakerRes.trades, filename: "data/FuturesScoutPaperTrades_stage4_taker.jsonl")

        // 4c. Sensitivitas Sesi: Chandelier 2.0x ATR + Maker + Session ON (12:30-16:00 UTC)
        let stage4SessionOnRes = runSimulation(stage: .stage4_variant_sessionOn, h1: h1Klines, m15: m15Klines, m5: m5Klines)
        printAblationRow(res: stage4SessionOnRes, label: "4c. SENSITIVITAS SESI ON (Chandelier 2xATR + Maker 0.02% + Session ON 12:30-16:00 UTC)")
        saveJsonl(trades: stage4SessionOnRes.trades, filename: "data/FuturesScoutPaperTrades_stage4_sessionOn.jsonl")

        // 4d. Sensitivitas Split: 30/70 Runner + Chandelier 2.0x ATR + Maker + Session OFF
        let stage4Runner3070Res = runSimulation(stage: .stage4_variant_runner3070, h1: h1Klines, m15: m15Klines, m5: m5Klines)
        printAblationRow(res: stage4Runner3070Res, label: "4d. SENSITIVITAS SPLIT 30/70 (30% Bank TP1 / 70% Runner Exp 1.618 + Chandelier 2xATR)")
        saveJsonl(trades: stage4Runner3070Res.trades, filename: "data/FuturesScoutPaperTrades_stage4_30_70.jsonl")

        // 4. Uji Validasi Out-of-Sample Anti-Overfitting pada KONFIGURASI PRIMER (Amendemen 2)
        print("\n--------------------------------------------------------------------------------")
        print("🛡️ BAGIAN C: VALIDASI OUT-OF-SAMPLE ANTI-OVERFITTING (KONFIGURASI PRIMER 4a)")
        print("   In-Sample (Train)   : 1 April 2026 – 31 Juli 2026 (4 Bulan)")
        print("   Out-of-Sample (Test): 1 Agustus 2026 – 26 September 2026 (~2 Bulan Unseen Holdout)")
        print("   ATURAN AUDITOR      : KEPUTUSAN LULUS/GUGUR HANYA DIBACA DARI KONFIGURASI PRIMER 4a")
        print("--------------------------------------------------------------------------------")

        let inSampleTrades = stage4PrimaryRes.trades.filter { $0.sampleType == "IN_SAMPLE" }
        let outSampleTrades = stage4PrimaryRes.trades.filter { $0.sampleType == "OUT_OF_SAMPLE" }

        let inSampleStats = computeMetrics(trades: inSampleTrades, initialEquity: initialCapital, stageName: "In-Sample (Apr-Jul)")
        let outSampleStats = computeMetrics(trades: outSampleTrades, initialEquity: inSampleStats.finalEquity, stageName: "Out-of-Sample (Aug-Sep)")

        printOutSampleRow(res: inSampleStats, label: "In-Sample Calibration (Apr-Jul 2026)")
        printOutSampleRow(res: outSampleStats, label: "Out-of-Sample Holdout (Aug-Sep 2026)")

        // 5. Analisis Distribusi Runner & Payoff (Mandat Agent 2)
        printRunnerAnalytics(trades: stage4PrimaryRes.trades, label: "Full 6-Month Primary Config")
        printRunnerAnalytics(trades: outSampleTrades, label: "Out-of-Sample Holdout Primary Config")

        // 6. Sweep Sensitivitas Fill-Rate Post-Only & Breakeven Fill Rate (Amendemen 3 Canon)
        runFillRateSweep(trades: stage4PrimaryRes.trades)

        // 7. Simpan Veto & Laporan Markdown Komprehensif
        saveVetoJsonl(vetoes: vetoedSignals, filename: "data/FuturesScoutVetoedSignals.jsonl")
        saveComprehensiveMarkdownReport(
            baseline: baselineRes,
            stage1: stage1Res,
            stage2a: stage2aRes,
            stage2b: stage2bRes,
            stage3: stage3Res,
            stage4Primary: stage4PrimaryRes,
            stage4Taker: stage4TakerRes,
            stage4SessionOn: stage4SessionOnRes,
            stage4Runner3070: stage4Runner3070Res,
            inSample: inSampleStats,
            outSample: outSampleStats,
            vetoCount: vetoedSignals.count
        )

        // 8. Evaluasi Standar Kelulusan Ketat Auditor
        let passInSampleGross = inSampleStats.grossExpectancy > 0.0
        let passOutSampleWR = outSampleStats.winRate >= 45.0
        let passOutSampleGross = outSampleStats.grossExpectancy > 0.0
        let passOutSampleNetExp = outSampleStats.netExpectancy > 0.0 // Syarat Primer: Net Exp OOS > 0
        let passOutSampleGrossPfThreshold = (outSampleStats.grossPF >= 1.25) || (outSampleStats.netExpectancy >= -5.0)
        let passOutSampleDD = outSampleStats.maxDrawdownPct < 6.00

        print("\n📋 EVALUASI STANDAR KELULUSAN KETAT AUDITOR (KONFIGURASI PRIMER 4a):")
        print(" [\(passInSampleGross ? "PASS" : "FAIL")] 1. In-Sample Gross Expectancy: \(fmtCurrency(inSampleStats.grossExpectancy)) (Target: > 0.0 USDT)")
        print(" [\(passOutSampleGross ? "PASS" : "FAIL")] 2. Out-of-Sample Gross Expectancy: \(fmtCurrency(outSampleStats.grossExpectancy)) (Target: > 0.0 USDT)")
        print(" [\(passOutSampleWR ? "PASS" : "FAIL")] 3. Out-of-Sample Win Rate: \(String(format: "%.1f", outSampleStats.winRate))% (Target: >= 45.0%)")
        print(" [\(passOutSampleNetExp ? "PASS" : "FAIL")] 4. Out-of-Sample Net Expectancy (Maker): \(fmtCurrency(outSampleStats.netExpectancy))/tr (Target: > 0.0 USDT)")
        print(" [\(passOutSampleGrossPfThreshold ? "PASS" : "FAIL")] 5. Out-of-Sample Gross PF >= 1.25 ATAU Net Exp >= -$5.00: Gross PF \(String(format: "%.2f", outSampleStats.grossPF))")
        print(" [\(passOutSampleDD ? "PASS" : "FAIL")] 6. Out-of-Sample Max Drawdown: \(String(format: "%.2f", outSampleStats.maxDrawdownPct))% (Target: < 6.00%)")

        let isApproved = passInSampleGross && passOutSampleGross && passOutSampleWR && passOutSampleNetExp && passOutSampleGrossPfThreshold && passOutSampleDD
        print("\n>>> HASIL AKHIR PILAR 3 (KONFIGURASI PRIMER OPSI 2): [\(isApproved ? "LULUS MEMENUHI PRE-REGISTERED GATE (SIAP PILAR 4 SHADOW MODE)" : "STOP-RULE TERPICU SECARA SAH: STRATEGI TIDAK TERMONETISASI PADA BTC M5")] <<<\n")
    }

    // MARK: - Simulator Loop Core
    private func runSimulation(
        stage: AblationStage,
        h1: [AstronacciKline],
        m15: [AstronacciKline],
        m5: [AstronacciKline],
        onVetoRecorded: ((CounterfactualVetoRecord) -> Void)? = nil
    ) -> SimulationResult {
        var currentEquity = initialCapital

        var h1Ptr = 0
        var m15Ptr = 0

        // Position Tracker Struct with Accrued PnL Persistence (Fix Akuntansi D)
        var activePos: (
            tradeId: String,
            dir: String,
            grade: String,
            entry: Double,
            sl: Double,
            initialSl: Double,
            tp1: Double,
            tp2: Double,
            totalSize: Double,
            remainingSize: Double,
            stage2: Bool,
            held: Int,
            accruedGross: Double,
            accruedFee: Double,
            mfe: Double,
            lastFundingMs: Int64,
            signalTime: Int64,
            fillTime: Int64,
            sampleType: String
        )? = nil

        var pending: (
            tradeId: String,
            dir: String,
            grade: String,
            entry: Double,
            sl: Double,
            tp1: Double,
            tp2: Double,
            size: Double,
            expiry: Int64,
            signalTime: Int64,
            sampleType: String
        )? = nil

        var completedTrades: [BacktestTradeRecord] = []

        // Parameter Fee & Max Hold Sesuai Tahap
        let isMakerStage: Bool
        let isStage4: Bool
        let runnerBankRatio: Double
        let sessionFilterOff: Bool

        switch stage {
        case .baseline, .stage1_dominantSwing, .stage2a_swingHighTP, .stage2b_exp1272TP:
            isMakerStage = false
            isStage4 = false
            runnerBankRatio = 0.5
            sessionFilterOff = false
        case .stage3_blendedFee:
            isMakerStage = true
            isStage4 = false
            runnerBankRatio = 0.5
            sessionFilterOff = false
        case .stage4_primary_runner5050_maker_sessionOff:
            isMakerStage = true
            isStage4 = true
            runnerBankRatio = 0.5
            sessionFilterOff = true
        case .stage4_variant_taker:
            isMakerStage = false
            isStage4 = true
            runnerBankRatio = 0.5
            sessionFilterOff = true
        case .stage4_variant_sessionOn:
            isMakerStage = true
            isStage4 = true
            runnerBankRatio = 0.5
            sessionFilterOff = false
        case .stage4_variant_runner3070:
            isMakerStage = true
            isStage4 = true
            runnerBankRatio = 0.3
            sessionFilterOff = true
        }

        let entryFeeRate = isMakerStage ? 0.0002 : 0.0005
        let tpExitFeeRate = isMakerStage ? 0.0002 : 0.0005
        let slExitFeeRate = 0.0005                         // SL selalu taker
        let slippageRate = 0.0005                          // 0.05% slippage

        let maxBarsHeld: Int
        switch stage {
        case .baseline, .stage1_dominantSwing:
            maxBarsHeld = 24                              // 2 jam untuk baseline/tahap 1 lama
        case .stage2a_swingHighTP, .stage2b_exp1272TP, .stage3_blendedFee,
             .stage4_primary_runner5050_maker_sessionOff, .stage4_variant_taker,
             .stage4_variant_sessionOn, .stage4_variant_runner3070:
            maxBarsHeld = 72                              // 6 jam (Intraday Swing Scalper Opsi A/2)
        }

        for i in 0..<m5.count {
            let curr = m5[i]
            let closeT = curr.timestamp + 300000

            while h1Ptr + 1 < h1.count && (h1[h1Ptr + 1].timestamp + 3600000) <= closeT { h1Ptr += 1 }
            while m15Ptr + 1 < m15.count && (m15[m15Ptr + 1].timestamp + 900000) <= closeT { m15Ptr += 1 }

            // 1. Kelola Posisi Aktif
            if var pos = activePos {
                pos.held += 1
                var finished = false
                var grossPnl = 0.0
                var feePaid = 0.0
                var exitReason = ""
                var exitPrice = 0.0

                // Track MFE
                if pos.dir == "LONG" {
                    if curr.high > pos.mfe { pos.mfe = curr.high }
                } else {
                    if curr.low < pos.mfe { pos.mfe = curr.low }
                }

                // Funding Rate Deduction (0.01% per 8 jam: 00:00, 08:00, 16:00 UTC)
                let curBucket = curr.timestamp / (8 * 3600 * 1000)
                let lastBucket = pos.lastFundingMs / (8 * 3600 * 1000)
                if curBucket > lastBucket && stage != .baseline && stage != .stage1_dominantSwing {
                    let fundingRate = 0.0001
                    pos.accruedFee += pos.entry * pos.remainingSize * fundingRate
                    pos.lastFundingMs = curr.timestamp
                }

                // Ambil nilai ATR M15 terkini untuk trailing stop Chandelier
                let curAtr: Double
                if m15Ptr >= 15 {
                    let slice = Array(m15[max(0, m15Ptr - 20)...m15Ptr])
                    curAtr = engine.calculateATR(period: 14, klines: slice)
                } else {
                    curAtr = 200.0
                }

                if pos.held >= maxBarsHeld {
                    // Max Hold Expired
                    exitPrice = curr.close
                    let diff = pos.dir == "LONG" ? (exitPrice - pos.entry) : (pos.entry - exitPrice)
                    let partialGross = diff * pos.remainingSize
                    let exitFee = exitPrice * pos.remainingSize * slExitFeeRate
                    grossPnl = pos.accruedGross + partialGross
                    feePaid = pos.accruedFee + exitFee
                    exitReason = "MAX_HOLD_EXPIRED"
                    finished = true
                } else if !pos.stage2 {
                    // Stage 1: Menunggu TP1 atau Initial SL
                    if pos.dir == "LONG" {
                        if curr.low <= pos.sl {
                            // Initial SL Hit
                            exitPrice = pos.sl * (1.0 - slippageRate)
                            grossPnl = (exitPrice - pos.entry) * pos.totalSize
                            feePaid = pos.accruedFee + (pos.entry * pos.totalSize * entryFeeRate) + (exitPrice * pos.totalSize * slExitFeeRate)
                            exitReason = "STOP_LOSS"
                            finished = true
                        } else if curr.high >= pos.tp1 {
                            // TP1 Hit -> Ambil porsi bank, kunci realized profit, pasang shield BEP
                            let bankSize = pos.totalSize * runnerBankRatio
                            exitPrice = pos.tp1
                            let partialGross = (exitPrice - pos.entry) * bankSize
                            let partialFee = (pos.entry * bankSize * entryFeeRate) + (exitPrice * bankSize * tpExitFeeRate)
                            pos.accruedGross += partialGross
                            pos.accruedFee += partialFee
                            pos.remainingSize -= bankSize
                            pos.sl = pos.entry // Shield ke BEP
                            pos.stage2 = true
                        }
                    } else {
                        // SHORT
                        if curr.high >= pos.sl {
                            exitPrice = pos.sl * (1.0 + slippageRate)
                            grossPnl = (pos.entry - exitPrice) * pos.totalSize
                            feePaid = pos.accruedFee + (pos.entry * pos.totalSize * entryFeeRate) + (exitPrice * pos.totalSize * slExitFeeRate)
                            exitReason = "STOP_LOSS"
                            finished = true
                        } else if curr.low <= pos.tp1 {
                            let bankSize = pos.totalSize * runnerBankRatio
                            exitPrice = pos.tp1
                            let partialGross = (pos.entry - exitPrice) * bankSize
                            let partialFee = (pos.entry * bankSize * entryFeeRate) + (exitPrice * bankSize * tpExitFeeRate)
                            pos.accruedGross += partialGross
                            pos.accruedFee += partialFee
                            pos.remainingSize -= bankSize
                            pos.sl = pos.entry // Shield ke BEP
                            pos.stage2 = true
                        }
                    }
                } else {
                    // Stage 2: Sisa posisi Runner (Mekanisme Chandelier 2.0x ATR atau BEP)
                    if isStage4 {
                        // Opsi 2 Canon: Chandelier 2.0x ATR Trailing Stop dengan BEP sebagai Floor
                        if pos.dir == "LONG" {
                            // Ratchet Chandelier SL ke atas
                            let chandelier = pos.mfe - (2.0 * curAtr)
                            if chandelier > pos.sl {
                                pos.sl = chandelier
                            }

                            if curr.low <= pos.sl {
                                // Trailing SL Hit atau BEP Hit
                                exitPrice = pos.sl
                                let runnerGross = (exitPrice - pos.entry) * pos.remainingSize
                                let exitFee = exitPrice * pos.remainingSize * slExitFeeRate
                                grossPnl = pos.accruedGross + runnerGross
                                feePaid = pos.accruedFee + exitFee
                                exitReason = pos.sl > pos.entry ? "RUNNER_TRAILING_STOP" : "TP1_THEN_BEP"
                                finished = true
                            } else if curr.high >= pos.tp2 {
                                // TP2 Hit (Fibonacci Expansion 1.618)
                                exitPrice = pos.tp2
                                let runnerGross = (exitPrice - pos.entry) * pos.remainingSize
                                let exitFee = exitPrice * pos.remainingSize * tpExitFeeRate // Limit maker exit
                                grossPnl = pos.accruedGross + runnerGross
                                feePaid = pos.accruedFee + exitFee
                                exitReason = "RUNNER_TP2"
                                finished = true
                            }
                        } else {
                            // SHORT
                            let chandelier = pos.mfe + (2.0 * curAtr)
                            if chandelier < pos.sl {
                                pos.sl = chandelier
                            }

                            if curr.high >= pos.sl {
                                exitPrice = pos.sl
                                let runnerGross = (pos.entry - exitPrice) * pos.remainingSize
                                let exitFee = exitPrice * pos.remainingSize * slExitFeeRate
                                grossPnl = pos.accruedGross + runnerGross
                                feePaid = pos.accruedFee + exitFee
                                exitReason = pos.sl < pos.entry ? "RUNNER_TRAILING_STOP" : "TP1_THEN_BEP"
                                finished = true
                            } else if curr.low <= pos.tp2 {
                                exitPrice = pos.tp2
                                let runnerGross = (pos.entry - exitPrice) * pos.remainingSize
                                let exitFee = exitPrice * pos.remainingSize * tpExitFeeRate
                                grossPnl = pos.accruedGross + runnerGross
                                feePaid = pos.accruedFee + exitFee
                                exitReason = "RUNNER_TP2"
                                finished = true
                            }
                        }
                    } else {
                        // Stage 2 lama (Fixed BEP tanpa Trailing Stop)
                        let half = pos.remainingSize
                        if pos.dir == "LONG" {
                            if curr.low <= pos.sl {
                                exitPrice = pos.sl
                                let exitFee = exitPrice * half * tpExitFeeRate
                                grossPnl = pos.accruedGross
                                feePaid = pos.accruedFee + exitFee
                                exitReason = "TP1_THEN_BEP"
                                finished = true
                            } else if curr.high >= pos.tp2 {
                                exitPrice = pos.tp2
                                let partialGross = (exitPrice - pos.entry) * half
                                let exitFee = exitPrice * half * tpExitFeeRate
                                grossPnl = pos.accruedGross + partialGross
                                feePaid = pos.accruedFee + exitFee
                                exitReason = "FULL_TP2"
                                finished = true
                            }
                        } else {
                            if curr.high >= pos.sl {
                                exitPrice = pos.sl
                                let exitFee = exitPrice * half * tpExitFeeRate
                                grossPnl = pos.accruedGross
                                feePaid = pos.accruedFee + exitFee
                                exitReason = "TP1_THEN_BEP"
                                finished = true
                            } else if curr.low <= pos.tp2 {
                                exitPrice = pos.tp2
                                let partialGross = (pos.entry - exitPrice) * half
                                let exitFee = exitPrice * half * tpExitFeeRate
                                grossPnl = pos.accruedGross + partialGross
                                feePaid = pos.accruedFee + exitFee
                                exitReason = "FULL_TP2"
                                finished = true
                            }
                        }
                    }
                }

                if finished {
                    let netPnl = grossPnl - feePaid
                    currentEquity += netPnl

                    let riskNominal = abs(pos.entry - pos.initialSl) * pos.totalSize
                    let rMult = riskNominal > 0 ? (netPnl / riskNominal) : 0.0

                    let mfeDist = pos.dir == "LONG" ? (pos.mfe - pos.entry) : (pos.entry - pos.mfe)
                    let mfeAtrRatio = curAtr > 0 ? (max(0, mfeDist) / curAtr) : 0.0

                    completedTrades.append(BacktestTradeRecord(
                        tradeId: pos.tradeId,
                        signalTimeUTC: formatDate(pos.signalTime),
                        fillTimeUTC: formatDate(pos.fillTime),
                        exitTimeUTC: formatDate(curr.timestamp),
                        direction: pos.dir,
                        grade: pos.grade,
                        entryPrice: pos.entry,
                        stopLossPrice: pos.initialSl,
                        tp1Price: pos.tp1,
                        tp2Price: pos.tp2,
                        exitPrice: exitPrice,
                        positionSizeBtc: pos.totalSize,
                        notionalUsd: pos.entry * pos.totalSize,
                        grossPnlUsd: grossPnl,
                        feePaidUsd: feePaid,
                        netPnlUsd: netPnl,
                        netPnlPct: (netPnl / (currentEquity - netPnl)) * 100.0,
                        rMultiple: rMult,
                        exitReason: exitReason,
                        barsHeld: pos.held,
                        mfePrice: pos.mfe,
                        mfeAtrRatio: mfeAtrRatio,
                        sampleType: pos.sampleType,
                        accountEquityAfter: currentEquity
                    ))
                    activePos = nil
                } else {
                    activePos = pos
                }
            }

            // 2. Cek Eksekusi Pending Limit Order
            if let ord = pending, activePos == nil {
                if curr.timestamp > ord.expiry {
                    pending = nil // Cancelled after 3 bars
                } else {
                    var filled = false
                    if ord.dir == "LONG" && curr.low <= ord.entry { filled = true }
                    else if ord.dir == "SHORT" && curr.high >= ord.entry { filled = true }

                    if filled {
                        activePos = (
                            tradeId: ord.tradeId,
                            dir: ord.dir,
                            grade: ord.grade,
                            entry: ord.entry,
                            sl: ord.sl,
                            initialSl: ord.sl,
                            tp1: ord.tp1,
                            tp2: ord.tp2,
                            totalSize: ord.size,
                            remainingSize: ord.size,
                            stage2: false,
                            held: 0,
                            accruedGross: 0.0,
                            accruedFee: (ord.entry * ord.size * entryFeeRate),
                            mfe: ord.entry,
                            lastFundingMs: curr.timestamp,
                            signalTime: ord.signalTime,
                            fillTime: curr.timestamp,
                            sampleType: ord.sampleType
                        )
                        pending = nil
                    }
                }
            }

            // 3. Evaluasi Sinyal Baru
            guard h1Ptr >= 200 && m15Ptr >= 48 && i >= 20 else { continue }

            let h1Slice = Array(h1[max(0, h1Ptr - 250)...h1Ptr])
            let m15Slice = Array(m15[max(0, m15Ptr - 150)...m15Ptr])
            let m5Slice = Array(m5[max(0, i - 100)...i])

            let isOverlap = sessionFilterOff ? true : checkLondonNyOverlap(timestampMs: closeT)

            let res = engine.evaluateConfluence(
                symbol: "BTC-USDT",
                klinesH1: h1Slice,
                klinesM15: m15Slice,
                klinesM5: m5Slice,
                isNewsClear: true,
                isLondonNyOverlap: isOverlap,
                accountEquity: currentEquity,
                maxLeverage: 10.0
            )

            // Koleksi Vetoed Signal untuk Audit Kontrafaktual
            if res.scoreBreakdown.totalScore >= 65 && !res.vetoCheck.isPassed && stage == .baseline {
                let dir = res.regime == .bullish ? "LONG" : (res.regime == .bearish ? "SHORT" : "NONE")
                if dir != "NONE" {
                    let entryP = curr.close
                    let atr = res.fibGrid.atr14 > 0 ? res.fibGrid.atr14 : 200.0
                    let slP = dir == "LONG" ? (entryP - atr * 1.5) : (entryP + atr * 1.5)
                    let tpP = dir == "LONG" ? (entryP + atr * 2.0) : (entryP - atr * 2.0)
                    var win = false
                    var simPnl = 0.0
                    for futureIdx in (i + 1)..<min(m5.count, i + 25) {
                        let f = m5[futureIdx]
                        if dir == "LONG" {
                            if f.low <= slP { win = false; simPnl = -100.0; break }
                            if f.high >= tpP { win = true; simPnl = 150.0; break }
                        } else {
                            if f.high >= slP { win = false; simPnl = -100.0; break }
                            if f.low <= tpP { win = true; simPnl = 150.0; break }
                        }
                    }
                    onVetoRecorded?(CounterfactualVetoRecord(
                        signalTimeUTC: formatDate(curr.timestamp),
                        direction: dir,
                        score: res.scoreBreakdown.totalScore,
                        rejectionReason: res.vetoCheck.rejectionReason ?? "VETO_REJECTED",
                        simulatedNetPnlUsd: simPnl,
                        isWinner: win
                    ))
                }
            }

            var allowSetup = false
            var finalPlan: (dir: String, entry: Double, sl: Double, tp1: Double, tp2: Double, size: Double)? = nil

            let atr = res.fibGrid.atr14
            let curClose = curr.close

            switch stage {
            case .baseline:
                // Logika lama: Jika lolos veto engine baseline
                if (res.finalStatus == "A_GRADE_SETUP" || res.finalStatus == "B_GRADE_ALERT"), let p = res.tradePlan {
                    allowSetup = true
                    finalPlan = (dir: p.direction, entry: p.entryPrice, sl: p.stopLossPrice, tp1: p.takeProfit1, tp2: p.takeProfit2, size: p.positionSize)
                }

            case .stage1_dominantSwing:
                // Tahap 1: Dominant Swing (>= 4.0x ATR, Lookback 48) dengan TP swing high lama
                if let swing = engine.detectDominantImpulsiveSwing(klines: m15Slice, atr: atr, lookbackBars: 48, minAtrMultiple: 4.0),
                   res.candleTrigger.isReversal {
                    let range = swing.swingHigh - swing.swingLow
                    let dirStr = res.regime == .bullish ? "LONG" : (res.regime == .bearish ? "SHORT" : "NONE")
                    if dirStr == "LONG" && swing.lowIndex < swing.highIndex && res.candleTrigger.isBullish {
                        let slP = swing.swingLow - (0.25 * atr)
                        let tp1P = swing.swingHigh
                        let tp2P = swing.swingLow + (range * 1.272)
                        let riskD = curClose - slP
                        let rewD = tp1P - curClose
                        let veto = AstronacciDeterministicEngine.evaluateVetoGate(
                            detectedRegime: res.regime,
                            candleTrigger: res.candleTrigger,
                            calculatedRR: rewD / riskD,
                            riskDist: riskD,
                            swingRange: range,
                            atr14: atr,
                            totalScore: res.scoreBreakdown.totalScore,
                            minRR: 1.0
                        )
                        if veto.isPassed {
                            let lot = floor((currentEquity * 0.01 / (riskD + curClose * 0.001)) * 1000.0) / 1000.0
                            if lot >= 0.001 {
                                allowSetup = true
                                finalPlan = (dir: "LONG", entry: curClose, sl: slP, tp1: tp1P, tp2: tp2P, size: min(lot, 1.0))
                            }
                        }
                    } else if dirStr == "SHORT" && swing.highIndex < swing.lowIndex && res.candleTrigger.isBearish {
                        let slP = swing.swingHigh + (0.25 * atr)
                        let tp1P = swing.swingLow
                        let tp2P = swing.swingHigh - (range * 1.272)
                        let riskD = slP - curClose
                        let rewD = curClose - tp1P
                        let veto = AstronacciDeterministicEngine.evaluateVetoGate(
                            detectedRegime: res.regime,
                            candleTrigger: res.candleTrigger,
                            calculatedRR: rewD / riskD,
                            riskDist: riskD,
                            swingRange: range,
                            atr14: atr,
                            totalScore: res.scoreBreakdown.totalScore,
                            minRR: 1.0
                        )
                        if veto.isPassed {
                            let lot = floor((currentEquity * 0.01 / (riskD + curClose * 0.001)) * 1000.0) / 1000.0
                            if lot >= 0.001 {
                                allowSetup = true
                                finalPlan = (dir: "SHORT", entry: curClose, sl: slP, tp1: tp1P, tp2: tp2P, size: min(lot, 1.0))
                            }
                        }
                    }
                }

            case .stage2a_swingHighTP, .stage3_blendedFee:
                // Sub-Ablasi 2a: Dominant Swing + SL Struct + TP1 di Swing High / Low (1.0 Retest)
                if let swing = engine.detectDominantImpulsiveSwing(klines: m15Slice, atr: atr, lookbackBars: 48, minAtrMultiple: 4.0),
                   res.candleTrigger.isReversal {
                    let range = swing.swingHigh - swing.swingLow
                    let dirStr = res.regime == .bullish ? "LONG" : (res.regime == .bearish ? "SHORT" : "NONE")
                    if dirStr == "LONG" && swing.lowIndex < swing.highIndex && res.candleTrigger.isBullish {
                        let slP = swing.swingLow - (0.25 * atr)
                        let tp1P = swing.swingHigh
                        let tp2P = swing.swingLow + (range * 1.272)
                        let riskD = curClose - slP
                        let rewD = tp1P - curClose
                        let veto = AstronacciDeterministicEngine.evaluateVetoGate(
                            detectedRegime: res.regime,
                            candleTrigger: res.candleTrigger,
                            calculatedRR: rewD / riskD,
                            riskDist: riskD,
                            swingRange: range,
                            atr14: atr,
                            totalScore: res.scoreBreakdown.totalScore,
                            minRR: 1.0
                        )
                        if veto.isPassed {
                            let lot = floor((currentEquity * 0.01 / (riskD + curClose * 0.001)) * 1000.0) / 1000.0
                            if lot >= 0.001 {
                                allowSetup = true
                                finalPlan = (dir: "LONG", entry: curClose, sl: slP, tp1: tp1P, tp2: tp2P, size: min(lot, 1.0))
                            }
                        }
                    } else if dirStr == "SHORT" && swing.highIndex < swing.lowIndex && res.candleTrigger.isBearish {
                        let slP = swing.swingHigh + (0.25 * atr)
                        let tp1P = swing.swingLow
                        let tp2P = swing.swingHigh - (range * 1.272)
                        let riskD = slP - curClose
                        let rewD = curClose - tp1P
                        let veto = AstronacciDeterministicEngine.evaluateVetoGate(
                            detectedRegime: res.regime,
                            candleTrigger: res.candleTrigger,
                            calculatedRR: rewD / riskD,
                            riskDist: riskD,
                            swingRange: range,
                            atr14: atr,
                            totalScore: res.scoreBreakdown.totalScore,
                            minRR: 1.0
                        )
                        if veto.isPassed {
                            let lot = floor((currentEquity * 0.01 / (riskD + curClose * 0.001)) * 1000.0) / 1000.0
                            if lot >= 0.001 {
                                allowSetup = true
                                finalPlan = (dir: "SHORT", entry: curClose, sl: slP, tp1: tp1P, tp2: tp2P, size: min(lot, 1.0))
                            }
                        }
                    }
                }

            case .stage2b_exp1272TP:
                // Sub-Ablasi 2b: Dominant Swing + SL Struct + TP1 di Fib Exp 1.272
                if let swing = engine.detectDominantImpulsiveSwing(klines: m15Slice, atr: atr, lookbackBars: 48, minAtrMultiple: 4.0),
                   res.candleTrigger.isReversal {
                    let range = swing.swingHigh - swing.swingLow
                    let dirStr = res.regime == .bullish ? "LONG" : (res.regime == .bearish ? "SHORT" : "NONE")
                    if dirStr == "LONG" && swing.lowIndex < swing.highIndex && res.candleTrigger.isBullish {
                        let slP = swing.swingLow - (0.25 * atr)
                        let tp1P = swing.swingLow + (range * 1.272)
                        let tp2P = swing.swingLow + (range * 1.618)
                        let riskD = curClose - slP
                        let rewD = tp1P - curClose
                        let veto = AstronacciDeterministicEngine.evaluateVetoGate(
                            detectedRegime: res.regime,
                            candleTrigger: res.candleTrigger,
                            calculatedRR: rewD / riskD,
                            riskDist: riskD,
                            swingRange: range,
                            atr14: atr,
                            totalScore: res.scoreBreakdown.totalScore,
                            minRR: 1.0
                        )
                        if veto.isPassed {
                            let lot = floor((currentEquity * 0.01 / (riskD + curClose * 0.001)) * 1000.0) / 1000.0
                            if lot >= 0.001 {
                                allowSetup = true
                                finalPlan = (dir: "LONG", entry: curClose, sl: slP, tp1: tp1P, tp2: tp2P, size: min(lot, 1.0))
                            }
                        }
                    } else if dirStr == "SHORT" && swing.highIndex < swing.lowIndex && res.candleTrigger.isBearish {
                        let slP = swing.swingHigh + (0.25 * atr)
                        let tp1P = swing.swingHigh - (range * 1.272)
                        let tp2P = swing.swingHigh - (range * 1.618)
                        let riskD = slP - curClose
                        let rewD = curClose - tp1P
                        let veto = AstronacciDeterministicEngine.evaluateVetoGate(
                            detectedRegime: res.regime,
                            candleTrigger: res.candleTrigger,
                            calculatedRR: rewD / riskD,
                            riskDist: riskD,
                            swingRange: range,
                            atr14: atr,
                            totalScore: res.scoreBreakdown.totalScore,
                            minRR: 1.0
                        )
                        if veto.isPassed {
                            let lot = floor((currentEquity * 0.01 / (riskD + curClose * 0.001)) * 1000.0) / 1000.0
                            if lot >= 0.001 {
                                allowSetup = true
                                finalPlan = (dir: "SHORT", entry: curClose, sl: slP, tp1: tp1P, tp2: tp2P, size: min(lot, 1.0))
                            }
                        }
                    }
                }

            case .stage4_primary_runner5050_maker_sessionOff,
                 .stage4_variant_taker,
                 .stage4_variant_sessionOn,
                 .stage4_variant_runner3070:
                // Opsi 2 Canon: Dominant Swing + SL Struct + TP1 Swing High (1.0) + Runner Exp 1.618
                if let swing = engine.detectDominantImpulsiveSwing(klines: m15Slice, atr: atr, lookbackBars: 48, minAtrMultiple: 4.0),
                   res.candleTrigger.isReversal {
                    let range = swing.swingHigh - swing.swingLow
                    let dirStr = res.regime == .bullish ? "LONG" : (res.regime == .bearish ? "SHORT" : "NONE")
                    if dirStr == "LONG" && swing.lowIndex < swing.highIndex && res.candleTrigger.isBullish {
                        let slP = swing.swingLow - (0.25 * atr)
                        let tp1P = swing.swingHigh
                        let tp2P = swing.swingLow + (range * 1.618)
                        let riskD = curClose - slP
                        let rewD = tp1P - curClose

                        let veto = AstronacciDeterministicEngine.evaluateVetoGate(
                            detectedRegime: res.regime,
                            candleTrigger: res.candleTrigger,
                            calculatedRR: rewD / riskD,
                            riskDist: riskD,
                            swingRange: range,
                            atr14: atr,
                            totalScore: res.scoreBreakdown.totalScore,
                            minRR: 1.0
                        )
                        if veto.isPassed {
                            let lot = floor((currentEquity * 0.01 / (riskD + curClose * 0.001)) * 1000.0) / 1000.0
                            if lot >= 0.001 {
                                allowSetup = true
                                finalPlan = (dir: "LONG", entry: curClose, sl: slP, tp1: tp1P, tp2: tp2P, size: min(lot, 1.0))
                            }
                        }
                    } else if dirStr == "SHORT" && swing.highIndex < swing.lowIndex && res.candleTrigger.isBearish {
                        let slP = swing.swingHigh + (0.25 * atr)
                        let tp1P = swing.swingLow
                        let tp2P = swing.swingHigh - (range * 1.618)
                        let riskD = slP - curClose
                        let rewD = curClose - tp1P

                        let veto = AstronacciDeterministicEngine.evaluateVetoGate(
                            detectedRegime: res.regime,
                            candleTrigger: res.candleTrigger,
                            calculatedRR: rewD / riskD,
                            riskDist: riskD,
                            swingRange: range,
                            atr14: atr,
                            totalScore: res.scoreBreakdown.totalScore,
                            minRR: 1.0
                        )
                        if veto.isPassed {
                            let lot = floor((currentEquity * 0.01 / (riskD + curClose * 0.001)) * 1000.0) / 1000.0
                            if lot >= 0.001 {
                                allowSetup = true
                                finalPlan = (dir: "SHORT", entry: curClose, sl: slP, tp1: tp1P, tp2: tp2P, size: min(lot, 1.0))
                            }
                        }
                    }
                }
            }

            if allowSetup, let plan = finalPlan, activePos == nil, pending == nil {
                let sampleTag = closeT < outOfSampleCutoffMs ? "IN_SAMPLE" : "OUT_OF_SAMPLE"
                let expiryT = closeT + 3 * 300000
                pending = (
                    tradeId: "TRD_\(formatDateShort(closeT))_\(plan.dir)",
                    dir: plan.dir,
                    grade: res.scoreBreakdown.totalScore >= 80 ? "A_GRADE" : "B_GRADE",
                    entry: plan.entry,
                    sl: plan.sl,
                    tp1: plan.tp1,
                    tp2: plan.tp2,
                    size: plan.size,
                    expiry: expiryT,
                    signalTime: closeT,
                    sampleType: sampleTag
                )
            }
        }

        return computeMetrics(trades: completedTrades, initialEquity: initialCapital, stageName: "\(stage)")
    }

    // MARK: - Metrics Computation Engine
    private func computeMetrics(trades: [BacktestTradeRecord], initialEquity: Double, stageName: String) -> SimulationResult {
        let total = trades.count
        let wins = trades.filter { $0.netPnlUsd > 0 }
        let losses = trades.filter { $0.netPnlUsd < 0 }
        let beps = trades.filter { abs($0.netPnlUsd) <= 0.5 }
        let winRate = total > 0 ? (Double(wins.count) / Double(total)) * 100.0 : 0.0

        let grossProfit = wins.reduce(0.0) { $0 + max(0, $1.grossPnlUsd) }
        let grossLoss = abs(losses.reduce(0.0) { $0 + min(0, $1.grossPnlUsd) })
        let grossPF = grossLoss > 0 ? (grossProfit / grossLoss) : (grossProfit > 0 ? 99.9 : 0.0)
        let grossExpectancy = total > 0 ? ((grossProfit - grossLoss) / Double(total)) : 0.0

        let netProfit = wins.reduce(0.0) { $0 + $1.netPnlUsd }
        let netLoss = abs(losses.reduce(0.0) { $0 + $1.netPnlUsd })
        let netPF = netLoss > 0 ? (netProfit / netLoss) : (netProfit > 0 ? 99.9 : 0.0)
        let totalNetPnl = trades.reduce(0.0) { $0 + $1.netPnlUsd }
        let netExpectancy = total > 0 ? (totalNetPnl / Double(total)) : 0.0

        let totalFees = trades.reduce(0.0) { $0 + $1.feePaidUsd }
        let finalEquity = initialEquity + totalNetPnl

        // Hitung Maximum Drawdown
        var peak = initialEquity
        var maxDdPct = 0.0
        var runningEq = initialEquity
        for t in trades {
            runningEq += t.netPnlUsd
            if runningEq > peak { peak = runningEq }
            let dd = peak > 0 ? ((peak - runningEq) / peak) * 100.0 : 0.0
            if dd > maxDdPct { maxDdPct = dd }
        }

        // Fast SL Rate: SL kena dalam <= 2 bar (10 menit)
        let fastSlCount = trades.filter { $0.exitReason == "STOP_LOSS" && $0.barsHeld <= 2 }.count
        let fastSlRate = total > 0 ? (Double(fastSlCount) / Double(total)) * 100.0 : 0.0

        let totalBars = trades.reduce(0) { $0 + $1.barsHeld }
        let avgBars = total > 0 ? Double(totalBars) / Double(total) : 0.0

        // Target Reachability Rate (Berapa trade yang mencapai MFE >= TP1)
        var reachedTargetCount = 0
        var mfeRatios: [Double] = []
        for t in trades {
            let reached = (t.direction == "LONG" && t.mfePrice >= t.tp1Price) || (t.direction == "SHORT" && t.mfePrice <= t.tp1Price)
            if reached { reachedTargetCount += 1 }
            let targetDist = abs(t.tp1Price - t.entryPrice)
            let mfeDist = t.direction == "LONG" ? (t.mfePrice - t.entryPrice) : (t.entryPrice - t.mfePrice)
            if targetDist > 0 {
                mfeRatios.append(max(0, mfeDist) / targetDist)
            }
        }
        let reachRate = total > 0 ? (Double(reachedTargetCount) / Double(total)) * 100.0 : 0.0
        mfeRatios.sort()
        let medianMfe = mfeRatios.count > 0 ? mfeRatios[mfeRatios.count / 2] : 0.0

        return SimulationResult(
            stageName: stageName,
            totalTrades: total,
            winCount: wins.count,
            lossCount: losses.count,
            bepCount: beps.count,
            winRate: winRate,
            grossProfit: grossProfit,
            grossLoss: grossLoss,
            grossPF: grossPF,
            grossExpectancy: grossExpectancy,
            netProfit: netProfit,
            netLoss: netLoss,
            netPF: netPF,
            netExpectancy: netExpectancy,
            totalFees: totalFees,
            finalEquity: finalEquity,
            maxDrawdownPct: maxDdPct,
            fastSlRate: fastSlRate,
            avgBarsHeld: avgBars,
            targetReachabilityRate: reachRate,
            medianMfeRatio: medianMfe,
            trades: trades
        )
    }

    // MARK: - Runner Analytics (Mandat Agent 2)
    func printRunnerAnalytics(trades: [BacktestTradeRecord], label: String) {
        let reachedTp1 = trades.filter { $0.exitReason != "STOP_LOSS" }
        let total = trades.count
        let reachedTp1Count = reachedTp1.count
        let tp1Pct = total > 0 ? (Double(reachedTp1Count) / Double(total)) * 100.0 : 0.0

        let fullTp2 = trades.filter { $0.exitReason == "RUNNER_TP2" || $0.exitReason == "FULL_TP2" }
        let trailingStop = trades.filter { $0.exitReason == "RUNNER_TRAILING_STOP" }
        let bepExits = trades.filter { $0.exitReason == "TP1_THEN_BEP" }
        let maxHoldExits = trades.filter { $0.exitReason == "MAX_HOLD_EXPIRED" }

        let grossTotal = trades.reduce(0.0) { $0 + $1.grossPnlUsd }

        print("\n--------------------------------------------------------------------------------")
        print("🏃 ANALISIS DETAIL DISTRIBUSI RUNNER & PAYOFF (\(label)):")
        print("--------------------------------------------------------------------------------")
        print(" • Total Trades Executed          : \(total)")
        print(" • Reach TP1 (Bank Triggered)     : \(reachedTp1Count) (\(String(format: "%.1f", tp1Pct))%)")
        print("   - Runner Reached 1.618 (TP2)   : \(fullTp2.count) (\(reachedTp1Count > 0 ? String(format: "%.1f", Double(fullTp2.count)/Double(reachedTp1Count)*100.0) : "0.0")% dari runner)")
        print("   - Runner Trailing Stop Hit     : \(trailingStop.count) (\(reachedTp1Count > 0 ? String(format: "%.1f", Double(trailingStop.count)/Double(reachedTp1Count)*100.0) : "0.0")% dari runner)")
        print("   - Runner Pullback to BEP       : \(bepExits.count) (\(reachedTp1Count > 0 ? String(format: "%.1f", Double(bepExits.count)/Double(reachedTp1Count)*100.0) : "0.0")% dari runner)")
        print("   - Runner Expired at Max Hold   : \(maxHoldExits.count) (\(reachedTp1Count > 0 ? String(format: "%.1f", Double(maxHoldExits.count)/Double(reachedTp1Count)*100.0) : "0.0")% dari runner)")
        print(" • Total Realized Gross PnL       : \(fmtCurrency(grossTotal))")
        print("--------------------------------------------------------------------------------")
    }

    // MARK: - Sweep Sensitivitas Fill-Rate Post-Only & Breakeven Fill Rate (Amendemen 3 Canon)
    func runFillRateSweep(trades: [BacktestTradeRecord]) {
        let oosTrades = trades.filter { $0.sampleType == "OUT_OF_SAMPLE" }
        guard !oosTrades.isEmpty else { return }

        print("\n--------------------------------------------------------------------------------")
        print("⚡ SWEEP SENSITIVITAS FILL-RATE POST-ONLY LIMIT ENTRY (OUT-OF-SAMPLE)")
        print("   Tujuan: Mengukur ketahanan strategi terhadap order tidak terisi (unfilled)")
        print("--------------------------------------------------------------------------------")
        print(String(format: "%-12@ | %-8@ | %-12@ | %-14@ | %-10@", "Fill Rate", "Trades", "Net PnL", "Net Exp/Tr", "Net PF"))
        print(String(repeating: "-", count: 68))

        let rates = [1.0, 0.90, 0.80, 0.70]
        var breakevenRate: Double? = nil

        for r in rates {
            let filtered = oosTrades.filter { t in
                let hashVal = abs(t.tradeId.hashValue) % 100
                return hashVal < Int(r * 100.0)
            }
            let stats = computeMetrics(trades: filtered, initialEquity: initialCapital, stageName: "FillRate_\(Int(r*100))%")
            print(String(format: "%-12@ | %-8d | $%-11.2f | $%-13.2f | %-10.2f",
                         "\(Int(r*100))%", stats.totalTrades, stats.finalEquity - initialCapital, stats.netExpectancy, stats.netPF))
            if stats.netExpectancy >= 0.0 && breakevenRate == nil {
                breakevenRate = r
            }
        }
        print("--------------------------------------------------------------------------------")
        if let be = breakevenRate {
            print("🎯 BREAKEVEN FILL RATE: \(Int(be * 100))% (Fill-rate minimum agar Net Expectancy OOS >= $0.00)")
        } else {
            print("⚠️ BREAKEVEN FILL RATE: > 100% (Strategi masih net-negatif pada fill-rate 100%)")
        }
        print("--------------------------------------------------------------------------------")
    }

    // MARK: - Row Printers
    private func printAblationRow(res: SimulationResult, label: String) {
        print("\n▶ \(label):")
        print("  • Trades: \(res.totalTrades) | Win Rate: \(String(format: "%.1f", res.winRate))% (\(res.winCount)W / \(res.lossCount)L / \(res.bepCount)BEP)")
        print("  • GROSS: PF \(String(format: "%.2f", res.grossPF)) | Exp: \(fmtCurrency(res.grossExpectancy))/tr | Profit: $\(String(format: "%.1f", res.grossProfit)) / Loss: $\(String(format: "%.1f", res.grossLoss))")
        print("  • NET  : PF \(String(format: "%.2f", res.netPF)) | Exp: \(fmtCurrency(res.netExpectancy))/tr | Net PnL: \(fmtCurrency(res.finalEquity - initialCapital)) | Fee: $\(String(format: "%.1f", res.totalFees))")
        print("  • Max Drawdown: \(String(format: "%.2f", res.maxDrawdownPct))% | Fast SL (<=2 bar): \(String(format: "%.1f", res.fastSlRate))%")
        print("  • Target Reachability (MFE >= TP1): \(String(format: "%.1f", res.targetReachabilityRate))% | Median MFE/Target: \(String(format: "%.2f", res.medianMfeRatio))x")
    }

    private func printOutSampleRow(res: SimulationResult, label: String) {
        print("\n▶ \(label):")
        print("  • Sample Size : \(res.totalTrades) trade")
        print("  • Win Rate    : \(String(format: "%.1f", res.winRate))% (\(res.winCount)W / \(res.lossCount)L)")
        print("  • Gross PF    : \(String(format: "%.2f", res.grossPF)) (Gross Exp: \(fmtCurrency(res.grossExpectancy)))")
        print("  • Net PF      : \(String(format: "%.2f", res.netPF)) (Net Exp: \(fmtCurrency(res.netExpectancy)))")
        print("  • Net PnL     : \(fmtCurrency(res.netProfit - res.netLoss)) USDT")
        print("  • Max Drawdown: \(String(format: "%.2f", res.maxDrawdownPct))%")
    }

    // MARK: - File Savers with Strict POSIX Trailing Newline
    private func saveJsonl(trades: [BacktestTradeRecord], filename: String) {
        let encoder = JSONEncoder()
        var lines: [String] = []
        for t in trades {
            if let d = try? encoder.encode(t), let s = String(data: d, encoding: .utf8) {
                lines.append(s)
            }
        }
        let content = lines.joined(separator: "\n") + "\n"
        try? content.write(to: URL(fileURLWithPath: filename), atomically: true, encoding: .utf8)
        print("💾 Jurnal transaksi (\(trades.count) baris POSIX) tersimpan di: \(filename)")
    }

    private func saveVetoJsonl(vetoes: [CounterfactualVetoRecord], filename: String) {
        let encoder = JSONEncoder()
        var lines: [String] = []
        for v in vetoes {
            if let d = try? encoder.encode(v), let s = String(data: d, encoding: .utf8) {
                lines.append(s)
            }
        }
        let content = lines.joined(separator: "\n") + "\n"
        try? content.write(to: URL(fileURLWithPath: filename), atomically: true, encoding: .utf8)
        print("💾 Artefak veto kontrafaktual (\(vetoes.count) baris POSIX) tersimpan di: \(filename)")
    }

    private func saveComprehensiveMarkdownReport(
        baseline: SimulationResult,
        stage1: SimulationResult,
        stage2a: SimulationResult,
        stage2b: SimulationResult,
        stage3: SimulationResult,
        stage4Primary: SimulationResult,
        stage4Taker: SimulationResult,
        stage4SessionOn: SimulationResult,
        stage4Runner3070: SimulationResult,
        inSample: SimulationResult,
        outSample: SimulationResult,
        vetoCount: Int
    ) {
        let path = "docs/futures-scout/06-pilar-3-backtest-report.md"

        let isWrPass = outSample.winRate >= 45.0 ? "✅ **PASSED**" : "❌ **FAIL**"
        let isGrossPfPass = outSample.grossPF >= 1.25 ? "✅ **PASSED**" : "❌ **FAIL**"
        let isNetExpPass = outSample.netExpectancy > 0.0 ? "✅ **PASSED**" : "❌ **FAIL**"
        let isNetPfPass = outSample.netPF >= 1.20 ? "✅ **PASSED**" : "❌ **FAIL**"
        let isDdPass = outSample.maxDrawdownPct < 6.0 ? "✅ **PASSED**" : "❌ **FAIL**"

        let doc = """
        # Laporan Verifikasi Pilar 3: Historical Backtest Opsi A & Opsi 2 (6 Bulan)

        **Instrumen**: `BTCUSDT` Perpetual Futures (BingX / Binance Archive)  
        **Periode Data**: 1 April 2026 – 26 September 2026 (51.417 Bar M5, 17.139 Bar M15, 4.285 Bar H1)  
        **Mesin Eksekusi**: [`AstronacciDeterministicEngine.swift`](file:///Users/heizaaa/Desktop/cdev/iza-3/boringNotch/Clicky/AstronacciDeterministicEngine.swift) (Swift Native Pure Math)  
        **Metodologi**: Pre-registered Dominant Impulsive Swing + Runner 50/50 Chandelier 2.0x ATR + Single Source Veto Gate

        ---

        ## 🔬 1. Hasil Studi Ablasi Bertingkat (Isolasi Efek Komponen Opsi A & Opsi 2)

        | Tahap Pengujian | Trades | Win Rate | Gross PF | Gross Exp | Net PF | Net PnL | Fast SL (<=2 bar) | Reachability (MFE>=TP1) |
        | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
        | **0. Baseline (Fix Akuntansi D)** | \(baseline.totalTrades) | \(String(format: "%.1f", baseline.winRate))% | \(String(format: "%.2f", baseline.grossPF)) | \(fmtCurrency(baseline.grossExpectancy)) | \(String(format: "%.2f", baseline.netPF)) | \(fmtCurrency(baseline.finalEquity - initialCapital)) | \(String(format: "%.1f", baseline.fastSlRate))% | \(String(format: "%.1f", baseline.targetReachabilityRate))% |
        | **1. Tahap 1 (Dominant Swing)** | \(stage1.totalTrades) | \(String(format: "%.1f", stage1.winRate))% | \(String(format: "%.2f", stage1.grossPF)) | \(fmtCurrency(stage1.grossExpectancy)) | \(String(format: "%.2f", stage1.netPF)) | \(fmtCurrency(stage1.finalEquity - initialCapital)) | \(String(format: "%.1f", stage1.fastSlRate))% | \(String(format: "%.1f", stage1.targetReachabilityRate))% |
        | **2a. Tahap 2a (TP Swing High 1.0)** | \(stage2a.totalTrades) | \(String(format: "%.1f", stage2a.winRate))% | \(String(format: "%.2f", stage2a.grossPF)) | \(fmtCurrency(stage2a.grossExpectancy)) | \(String(format: "%.2f", stage2a.netPF)) | \(fmtCurrency(stage2a.finalEquity - initialCapital)) | \(String(format: "%.1f", stage2a.fastSlRate))% | \(String(format: "%.1f", stage2a.targetReachabilityRate))% |
        | **2b. Tahap 2b (TP Exp 1.272)** | \(stage2b.totalTrades) | \(String(format: "%.1f", stage2b.winRate))% | \(String(format: "%.2f", stage2b.grossPF)) | \(fmtCurrency(stage2b.grossExpectancy)) | \(String(format: "%.2f", stage2b.netPF)) | \(fmtCurrency(stage2b.finalEquity - initialCapital)) | \(String(format: "%.1f", stage2b.fastSlRate))% | \(String(format: "%.1f", stage2b.targetReachabilityRate))% |
        | **3. Tahap 3 (Blended Fee 2a)** | \(stage3.totalTrades) | \(String(format: "%.1f", stage3.winRate))% | \(String(format: "%.2f", stage3.grossPF)) | \(fmtCurrency(stage3.grossExpectancy)) | \(String(format: "%.2f", stage3.netPF)) | \(fmtCurrency(stage3.finalEquity - initialCapital)) | \(String(format: "%.1f", stage3.fastSlRate))% | \(String(format: "%.1f", stage3.targetReachabilityRate))% |
        | **4a. PRIMER (Chandelier + Maker + 24h)** | **\(stage4Primary.totalTrades)** | **\(String(format: "%.1f", stage4Primary.winRate))%** | **\(String(format: "%.2f", stage4Primary.grossPF))** | **\(fmtCurrency(stage4Primary.grossExpectancy))** | **\(String(format: "%.2f", stage4Primary.netPF))** | **\(fmtCurrency(stage4Primary.finalEquity - initialCapital))** | **\(String(format: "%.1f", stage4Primary.fastSlRate))%** | **\(String(format: "%.1f", stage4Primary.targetReachabilityRate))%** |
        | **4b. Sensitivitas Taker** | \(stage4Taker.totalTrades) | \(String(format: "%.1f", stage4Taker.winRate))% | \(String(format: "%.2f", stage4Taker.grossPF)) | \(fmtCurrency(stage4Taker.grossExpectancy)) | \(String(format: "%.2f", stage4Taker.netPF)) | \(fmtCurrency(stage4Taker.finalEquity - initialCapital)) | \(String(format: "%.1f", stage4Taker.fastSlRate))% | \(String(format: "%.1f", stage4Taker.targetReachabilityRate))% |
        | **4c. Sensitivitas Sesi ON** | \(stage4SessionOn.totalTrades) | \(String(format: "%.1f", stage4SessionOn.winRate))% | \(String(format: "%.2f", stage4SessionOn.grossPF)) | \(fmtCurrency(stage4SessionOn.grossExpectancy)) | \(String(format: "%.2f", stage4SessionOn.netPF)) | \(fmtCurrency(stage4SessionOn.finalEquity - initialCapital)) | \(String(format: "%.1f", stage4SessionOn.fastSlRate))% | \(String(format: "%.1f", stage4SessionOn.targetReachabilityRate))% |
        | **4d. Sensitivitas Split 30/70** | \(stage4Runner3070.totalTrades) | \(String(format: "%.1f", stage4Runner3070.winRate))% | \(String(format: "%.2f", stage4Runner3070.grossPF)) | \(fmtCurrency(stage4Runner3070.grossExpectancy)) | \(String(format: "%.2f", stage4Runner3070.netPF)) | \(fmtCurrency(stage4Runner3070.finalEquity - initialCapital)) | \(String(format: "%.1f", stage4Runner3070.fastSlRate))% | \(String(format: "%.1f", stage4Runner3070.targetReachabilityRate))% |

        ---

        ## 🛡️ 2. Validasi Out-of-Sample Anti-Overfitting (Konfigurasi Primer 4a)

        | Parameter Validasi | In-Sample (Apr–Jul 2026) | Out-of-Sample (Agu–Sep 2026) | Target Gerbang Auditor | Status Faktual |
        | :--- | :--- | :--- | :--- | :--- |
        | **Ukuran Sampel** | \(inSample.totalTrades) trade | \(outSample.totalTrades) trade | >= 10 per split | \(inSample.totalTrades >= 10 && outSample.totalTrades >= 10 ? "✅ **PASSED**" : "❌ **FAIL**") |
        | **Win Rate** | **\(String(format: "%.1f", inSample.winRate))%** | **\(String(format: "%.1f", outSample.winRate))%** | >= 45.0% | \(isWrPass) |
        | **Gross Profit Factor** | **\(String(format: "%.2f", inSample.grossPF))** | **\(String(format: "%.2f", outSample.grossPF))** | >= 1.25 | \(isGrossPfPass) |
        | **Net Expectancy per Trade** | **\(fmtCurrency(inSample.netExpectancy))** | **\(fmtCurrency(outSample.netExpectancy))** | > 0.0 USDT | \(isNetExpPass) |
        | **Net Profit Factor** | **\(String(format: "%.2f", inSample.netPF))** | **\(String(format: "%.2f", outSample.netPF))** | > 1.20 | \(isNetPfPass) |
        | **Maximum Drawdown** | **\(String(format: "%.2f", inSample.maxDrawdownPct))%** | **\(String(format: "%.2f", outSample.maxDrawdownPct))%** | < 6.00% | \(isDdPass) |

        ---

        ## 📁 3. Daftar Berkas Bukti & Artefak Data Berversi

        1. **Konfigurasi Primer 4a**: [`data/FuturesScoutPaperTrades_stage4_primary.jsonl`](file:///Users/heizaaa/Desktop/cdev/iza-3/data/FuturesScoutPaperTrades_stage4_primary.jsonl) (\(stage4Primary.totalTrades) trade).
        2. **Sensitivitas Taker 4b**: [`data/FuturesScoutPaperTrades_stage4_taker.jsonl`](file:///Users/heizaaa/Desktop/cdev/iza-3/data/FuturesScoutPaperTrades_stage4_taker.jsonl) (\(stage4Taker.totalTrades) trade).
        3. **Sensitivitas Sesi ON 4c**: [`data/FuturesScoutPaperTrades_stage4_sessionOn.jsonl`](file:///Users/heizaaa/Desktop/cdev/iza-3/data/FuturesScoutPaperTrades_stage4_sessionOn.jsonl) (\(stage4SessionOn.totalTrades) trade).
        4. **Sensitivitas Split 30/70 4d**: [`data/FuturesScoutPaperTrades_stage4_30_70.jsonl`](file:///Users/heizaaa/Desktop/cdev/iza-3/data/FuturesScoutPaperTrades_stage4_30_70.jsonl) (\(stage4Runner3070.totalTrades) trade).
        5. **Sinyal Ditolak Veto**: [`data/FuturesScoutVetoedSignals.jsonl`](file:///Users/heizaaa/Desktop/cdev/iza-3/data/FuturesScoutVetoedSignals.jsonl) (\(vetoCount) sinyal ditolak kontrafaktual).
        6. **Engine Produksi Terkalibrasi**: [`boringNotch/Clicky/AstronacciDeterministicEngine.swift`](file:///Users/heizaaa/Desktop/cdev/iza-3/boringNotch/Clicky/AstronacciDeterministicEngine.swift).
        """

        try? doc.write(to: URL(fileURLWithPath: path), atomically: true, encoding: .utf8)
        print("📄 Laporan eksekutif Markdown tersimpan di: \(path)")
    }

    // MARK: - Utilities
    private func loadKlines(from path: String) -> [RawHistoricalKline]? {
        guard let d = try? Data(contentsOf: URL(fileURLWithPath: path)) else { return nil }
        return try? JSONDecoder().decode([RawHistoricalKline].self, from: d)
    }

    private func checkLondonNyOverlap(timestampMs: Int64) -> Bool {
        let date = Date(timeIntervalSince1970: Double(timestampMs) / 1000.0)
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let hour = cal.component(.hour, from: date)
        let min = cal.component(.minute, from: date)
        if hour == 12 && min >= 30 { return true }
        if hour >= 13 && hour < 16 { return true }
        return false
    }

    private func formatDate(_ timestampMs: Int64) -> String {
        return ISO8601DateFormatter().string(from: Date(timeIntervalSince1970: Double(timestampMs) / 1000.0))
    }

    private func formatDateShort(_ timestampMs: Int64) -> String {
        let date = Date(timeIntervalSince1970: Double(timestampMs) / 1000.0)
        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd_HHmm"
        f.timeZone = TimeZone(identifier: "UTC")
        return f.string(from: date)
    }
}

func fmtCurrency(_ val: Double) -> String {
    let sign = val >= 0 ? "+" : "-"
    return String(format: "%@$%.2f", sign, abs(val))
}
