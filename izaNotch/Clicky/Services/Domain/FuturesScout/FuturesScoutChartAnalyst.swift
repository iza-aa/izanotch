//
//  FuturesScoutChartAnalyst.swift
//  izaNotch
//
//  On-Demand Chart Analyst (Option B Canon)
//  Desktop CUA & Reporting Coordinator (@MainActor)
//  Coordinates TradingView automation, live market data fetching, pure mathematical analysis,
//  and dual-payload presentation (chat markdown card + clean TTS narrative).
//

import AppKit
import Carbon.HIToolbox
import Defaults
import Foundation

@MainActor
public final class FuturesScoutChartAnalyst {
    public static let shared = FuturesScoutChartAnalyst()

    private let engine = AstronacciDeterministicEngine.shared
    private let marketData = FuturesScoutMarketDataService.shared
    private let dispatcher = TradingViewActionDispatcher.shared

    private init() {}

    /// Executes complete on-demand chart analysis workflow
    public func analyzeAndReport(symbol rawSymbol: String, preferredTimeframe: String = "15") async {
        let exchangeSymbol = FuturesScoutMarketDataService.normalizeSymbolForExchange(rawSymbol)
        let tvSymbol = FuturesScoutMarketDataService.normalizeSymbolForTradingView(rawSymbol)
        let displaySymbol = exchangeSymbol.replacingOccurrences(of: "-", with: "/")
        let traceId = "analyst-\(UUID().uuidString.prefix(8))"

        ClickyLogger.info("[CHART_ANALYST]", "Starting on-demand analysis for \(displaySymbol) (trace: \(traceId))...")
        reportStatus("Mengambil data pasar & menganalisis \(displaySymbol)...")

        // 1. Fetch Live Market Data First
        var klinesH1: [AstronacciKline] = []
        var klinesM15: [AstronacciKline] = []
        var klinesM5: [AstronacciKline] = []

        do {
            async let fetchH1 = marketData.fetchKlines(symbol: exchangeSymbol, interval: "1h", limit: 220)
            async let fetchM15 = marketData.fetchKlines(symbol: exchangeSymbol, interval: "15m", limit: 60)
            async let fetchM5 = marketData.fetchKlines(symbol: exchangeSymbol, interval: "5m", limit: 30)

            (klinesH1, klinesM15, klinesM5) = try await (fetchH1, fetchM15, fetchM5)
        } catch {
            ClickyLogger.error("[CHART_ANALYST]", "Failed to fetch market klines: \(error.localizedDescription)")

            // Fallback: Still activate TradingView and switch to requested symbol under locked trace
            let fallbackChain = TradingViewActionPayload(
                actionType: .chain,
                subActions: [
                    TradingViewActionPayload(actionType: .symbol, parameter: tvSymbol),
                    TradingViewActionPayload(actionType: .timeframe, parameter: preferredTimeframe),
                    TradingViewActionPayload(actionType: .resetScale)
                ]
            )
            _ = await dispatcher.execute(action: fallbackChain, traceId: traceId)

            let fallbackReport = """
            ### 📊 Analisis Teknikal: \(displaySymbol)
            *Koneksi data pasar terganggu: \(error.localizedDescription)*

            Chart telah dibuka di TradingView pada simbol **\(tvSymbol)** dan timeframe **\(preferredTimeframe)**.
            Silakan amati candlestick langsung di layar Anda.

            > ⚠️ **Catatan Edukasi**: Analisis teknikal objektif berbasis metodologi Astronacci-Fibonacci. Bukan sinyal otomatis atau rekomendasi finansial.
            """
            let fallbackSpeech = "Koneksi data pasar terganggu untuk \(rawSymbol). Chart telah dibuka di TradingView."
            await deliverReport(fallbackReport, speechNarrative: fallbackSpeech)
            return
        }

        // 2. Mathematical & Time Analysis via Pure Core Analyst (Decoupled Engine)
        let analysisResult = FuturesScoutCoreAnalyst.analyze(
            rawSymbol: rawSymbol,
            klinesH1: klinesH1,
            klinesM15: klinesM15,
            klinesM5: klinesM5,
            referenceDate: Date(),
            engine: engine
        )

        switch analysisResult {
        case .failure(let error):
            ClickyLogger.warning("[CHART_ANALYST]", "Insufficient klines for analysis: \(error)")
            let emptyReport = "Maaf, data kandel tidak mencukupi untuk menganalisis \(displaySymbol) secara objektif."
            let emptySpeech = "Maaf, data kandel pasar belum mencukupi untuk menganalisis \(displaySymbol)."
            await deliverReport(emptyReport, speechNarrative: emptySpeech)

        case .success(let result):
            reportStatus("Mengonfigurasi TradingView & memetakan level...")

            // 3. Physical CUA Execution: Single-Flight Locked Chain
            var subActions: [TradingViewActionPayload] = [
                TradingViewActionPayload(actionType: .symbol, parameter: tvSymbol),
                TradingViewActionPayload(actionType: .timeframe, parameter: preferredTimeframe)
            ]

            if Defaults[.autoCollapseTradingViewSidebar] {
                subActions.append(TradingViewActionPayload(actionType: .toggleSidebar))
            }

            // Grounded residual drawing purge via Universal Command Palette (Cmd+K -> "Remove drawings")
            subActions.append(TradingViewActionPayload(actionType: .clearDrawings))

            // P3 Canon: Status-Differentiated Overlay Injection
            // Choppy market (.standAsideChoppy) returns empty script -> skipped automatically (Zero Mutation).
            // Outside GP (.standAsideOutsideGP) injects reference lines (Dotted GP + Swings + Status note).
            // In GP / Setup (.inGoldenPocketWaiting, .setupDetected) injects full Trade Plan Box.
            if Defaults[.autoDrawFibonacciOverlay] {
                let pineScript = FuturesScoutCoreAnalyst.generatePineScriptOverlay(result: result)
                if !pineScript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    subActions.append(TradingViewActionPayload(actionType: .injectPineScript, pineScript: pineScript))
                }
            }

            subActions.append(TradingViewActionPayload(actionType: .resetScale))

            let cuaChain = TradingViewActionPayload(actionType: .chain, subActions: subActions)
            let cuaOk = await dispatcher.execute(action: cuaChain, traceId: traceId)

            // 4. Native Cua-Driver Action Cursor Pointing Gesture (Foto 1 Cursor)
            if cuaOk,
               let bounds = TradingViewInputSupport.getTradingViewWindowBounds(),
               let winInfo = TradingViewInputSupport.getTradingViewMainWindowInfo(),
               let pid = TradingViewInputSupport.tradingViewPID,
               TradingViewInputSupport.isTradingViewFrontmost() {
                let snapW = bounds.width * 2.0
                let snapH = bounds.height * 2.0
                let safePxX = snapW * 0.65
                let safePxY = snapH * 0.50
                _ = try? await CuaDriverClient.shared.moveCursor(pid: pid, windowId: Int64(winInfo.windowId), x: safePxX, y: safePxY)
                ClickyLogger.info("[CHART_ANALYST]", "Native CuaDriver cursor pointed to safe canvas coordinate (\(Int(safePxX)), \(Int(safePxY)))")
                try? await Task.sleep(for: .milliseconds(400))
                _ = TradingViewInputSupport.pressKey(CGKeyCode(kVK_Escape))
            }

            // 5. Dual-Payload Presentation Delivery
            var (cardMarkdown, voiceNarrative) = FuturesScoutCoreAnalyst.renderPresentation(result: result)
            if !cuaOk {
                cardMarkdown += "\n\n> ⚠️ **Catatan Chart**: Jendela TradingView belum beralih ke simbol \(displaySymbol) (verifikasi judul jendela tidak lolos). Mutasi chart dan overlay Fibonacci dibatalkan demi keamanan."
            }
            ClickySoundEngine.shared.play(.done)
            await deliverReport(cardMarkdown, speechNarrative: voiceNarrative)
        }
    }

    // MARK: - Multi-Market Scanning Radar (Reviewer Canon)

    /// Fetches klines with strict budget timeout per coin.
    /// Reviewer Condition 1: Budget timeout per koin + skip on fail (no hanging or full-scan abort).
    private func fetchKlinesWithTimeout(
        exchangeSymbol: String,
        timeoutSeconds: Double = 3.0
    ) async -> (h1: [AstronacciKline], m15: [AstronacciKline], m5: [AstronacciKline])? {
        let fetchTask = Task {
            async let fetchH1 = self.marketData.fetchKlines(symbol: exchangeSymbol, interval: "1h", limit: 220)
            async let fetchM15 = self.marketData.fetchKlines(symbol: exchangeSymbol, interval: "15m", limit: 60)
            async let fetchM5 = self.marketData.fetchKlines(symbol: exchangeSymbol, interval: "5m", limit: 30)
            return try await (fetchH1, fetchM15, fetchM5)
        }

        let timeoutTask = Task {
            try await Task.sleep(nanoseconds: UInt64(timeoutSeconds * 1_000_000_000))
            fetchTask.cancel()
        }

        defer {
            timeoutTask.cancel()
        }

        do {
            return try await fetchTask.value
        } catch {
            return nil
        }
    }

    /// Executes multi-market radar screening, deterministic top-pick selection, guided CUA navigation,
    /// and unified Market Overview presentation delivery.
    /// Reviewer Canon:
    /// - 1. Budget timeout per coin + skip on fail
    /// - 2. Exact classification (Hot/Approaching/Dead) using SSOT CoreAnalyst.analyze
    /// - 3. Deterministic top-pick (Hot first, tie-break smallest GP distance; Pine only on top-pick; 0 mutation on Choppy)
    /// - 4. Proven clearDrawings via actionType: .clearDrawings
    /// - 5. Single traceId, clean TTS < 300 char without markdown, formatPrice
    public func analyzeMarketAndReport(
        customMarkets: [String]? = nil,
        preferredTimeframe: String = "15"
    ) async {
        let defaultUniverse = [
            "BTC", "ETH", "SOL", "XRP", "DOGE",
            "SUI", "AVAX", "NEAR", "LINK", "ADA",
            "BNB", "LTC", "BCH", "UNI", "INJ",
            "APT", "TAO"
        ]
        let rawUniverse = (customMarkets?.isEmpty == false) ? customMarkets! : defaultUniverse
        let maxLimit = 20
        let universe: [String]
        if rawUniverse.count > maxLimit {
            ClickyLogger.warning("[CHART_ANALYST]", "Custom market list (\(rawUniverse.count) coins) exceeds safety limit of \(maxLimit). Clamping to first \(maxLimit): \(rawUniverse.prefix(maxLimit).joined(separator: ", "))")
            universe = Array(rawUniverse.prefix(maxLimit))
        } else {
            universe = rawUniverse
        }
        let traceId = "market-\(UUID().uuidString.prefix(8))"
        let referenceDate = Date()

        ClickyLogger.info("[CHART_ANALYST]", "Starting multi-market radar scan for [\(universe.joined(separator: ", "))] (trace: \(traceId))...")
        reportStatus("Memindai pasar kripto (Market Radar)...")

        // 1. Parallel Pre-Screening Radar with Budget Timeout
        var evaluatedCandidates: [MarketCandidateEvaluation] = []

        await withTaskGroup(of: MarketCandidateEvaluation.self) { group in
            for rawSym in universe {
                let cleanRaw = rawSym.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
                let exchangeSymbol = FuturesScoutMarketDataService.normalizeSymbolForExchange(cleanRaw)
                let displaySymbol = exchangeSymbol.replacingOccurrences(of: "-", with: "/")

                group.addTask {
                    guard let klines = await self.fetchKlinesWithTimeout(exchangeSymbol: exchangeSymbol, timeoutSeconds: 3.0) else {
                        ClickyLogger.warning("[CHART_ANALYST]", "Market Radar: Timeout or fetch failure for \(cleanRaw) (skip on fail)")
                        return MarketCandidateEvaluation(
                            symbol: cleanRaw,
                            displaySymbol: displaySymbol,
                            classification: .dataUnavailable,
                            analysisResult: nil,
                            distanceToGPAtrMultiple: nil,
                            failureReason: "Timeout/Network"
                        )
                    }

                    let analysis = FuturesScoutCoreAnalyst.analyze(
                        rawSymbol: cleanRaw,
                        klinesH1: klines.h1,
                        klinesM15: klines.m15,
                        klinesM5: klines.m5,
                        referenceDate: referenceDate,
                        engine: self.engine
                    )

                    switch analysis {
                    case .success(let res):
                        let candidate = FuturesScoutCoreAnalyst.evaluateMarketCandidate(rawSymbol: cleanRaw, result: res)
                        let distStr = candidate.distanceToGPAtrMultiple != nil ? String(format: "%.1fx ATR", candidate.distanceToGPAtrMultiple!) : "nil"
                        ClickyLogger.info("[CHART_ANALYST]", "Market Radar [\(cleanRaw)]: \(candidate.classification.rawValue) (Regime: \(res.regimeResult.regime.rawValue), Dist: \(distStr))")
                        return candidate
                    case .failure(let err):
                        ClickyLogger.warning("[CHART_ANALYST]", "Market Radar [\(cleanRaw)]: Analysis failure (\(err.localizedDescription))")
                        return MarketCandidateEvaluation(
                            symbol: cleanRaw,
                            displaySymbol: displaySymbol,
                            classification: .dataUnavailable,
                            analysisResult: nil,
                            distanceToGPAtrMultiple: nil,
                            failureReason: err.localizedDescription
                        )
                    }
                }
            }

            for await candidate in group {
                evaluatedCandidates.append(candidate)
            }
        }

        // Sort candidates to preserve consistent ordering matching universe
        evaluatedCandidates.sort { a, b in
            let idxA = universe.firstIndex(of: a.symbol) ?? 999
            let idxB = universe.firstIndex(of: b.symbol) ?? 999
            return idxA < idxB
        }

        // 2. Deterministic Top-Pick Selection
        let topPick = FuturesScoutCoreAnalyst.selectTopPickCandidate(candidates: evaluatedCandidates)
        var cuaOk = true
        var targetTvSymbol: String? = nil

        if let pick = topPick, let res = pick.analysisResult {
            let tvSym = res.tvSymbol
            targetTvSymbol = tvSym
            ClickyLogger.info("[CHART_ANALYST]", "Market Radar Top-Pick: \(pick.symbol) (\(pick.classification.rawValue)), TV Target: \(tvSym)")

            // 3. Guided CUA Navigation (Single Flight Locked Chain for Top-Pick ONLY)
            var subActions: [TradingViewActionPayload] = [
                TradingViewActionPayload(actionType: .symbol, parameter: tvSym),
                TradingViewActionPayload(actionType: .timeframe, parameter: preferredTimeframe)
            ]

            if Defaults[.autoCollapseTradingViewSidebar] {
                subActions.append(TradingViewActionPayload(actionType: .toggleSidebar))
            }

            // Grounded residual drawing & indicator purge via Universal Command Palette (Cmd+K -> "Remove drawings", "Remove indicators")
            subActions.append(TradingViewActionPayload(actionType: .clearDrawings))

            // Status-Differentiated Overlay Injection (Non-Choppy Top-Picks: Hot & Approaching)
            // Choppy market (.standAsideChoppy) returns empty script -> skipped automatically.
            // Outside GP (.standAsideOutsideGP) injects Mode 1 reference lines & HUD table (Entry, TP, SL, R:R).
            // In GP / Setup (.inGoldenPocketWaiting, .setupDetected) injects Mode 2 full Trade Plan Box.
            if Defaults[.autoDrawFibonacciOverlay] {
                let pineScript = FuturesScoutCoreAnalyst.generatePineScriptOverlay(result: res)
                if !pineScript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    subActions.append(TradingViewActionPayload(actionType: .injectPineScript, pineScript: pineScript))
                }
            }

            subActions.append(TradingViewActionPayload(actionType: .resetScale))

            let cuaChain = TradingViewActionPayload(actionType: .chain, subActions: subActions)
            cuaOk = await dispatcher.execute(action: cuaChain, traceId: traceId)

            // 4. Native Cua-Driver Action Cursor Pointing Gesture
            if cuaOk,
               let bounds = TradingViewInputSupport.getTradingViewWindowBounds(),
               let winInfo = TradingViewInputSupport.getTradingViewMainWindowInfo(),
               let pid = TradingViewInputSupport.tradingViewPID,
               TradingViewInputSupport.isTradingViewFrontmost() {
                let snapW = bounds.width * 2.0
                let snapH = bounds.height * 2.0
                let safePxX = snapW * 0.65
                let safePxY = snapH * 0.50
                _ = try? await CuaDriverClient.shared.moveCursor(pid: pid, windowId: Int64(winInfo.windowId), x: safePxX, y: safePxY)
                ClickyLogger.info("[CHART_ANALYST]", "Native CuaDriver cursor pointed to chart canvas (\(Int(safePxX)), \(Int(safePxY)))")
                try? await Task.sleep(for: .milliseconds(400))
                _ = TradingViewInputSupport.pressKey(CGKeyCode(kVK_Escape))
            }
        } else {
            // Choppy / All Flat / Unavailable -> 100% Zero-Touch CUA (Zero Mutation Guarantee)
            // TradingView is completely untouched: 0 symbol switch, 0 clearDrawings, 0 cursor movement.
            ClickyLogger.info("[CHART_ANALYST]", "Market Radar: All markets Choppy/Unavailable. 100% Zero-Touch CUA enforced — bypassing TradingView dispatcher and cursor completely.")
        }

        // 5. Dual-Payload Presentation Delivery (Market Overview Card + Clean TTS)
        var (cardMarkdown, voiceNarrative) = FuturesScoutCoreAnalyst.renderMarketOverview(
            candidates: evaluatedCandidates,
            referenceDate: referenceDate,
            topPick: topPick
        )

        if let tvSym = targetTvSymbol, !cuaOk {
            cardMarkdown += "\n\n> ⚠️ **Catatan Chart**: Jendela TradingView belum beralih ke simbol \(tvSym) (verifikasi judul jendela tidak lolos). Mutasi chart dibatalkan demi keamanan."
        }

        ClickySoundEngine.shared.play(.done)
        await deliverReport(cardMarkdown, speechNarrative: voiceNarrative)
    }

    // MARK: - CompanionReportPresenter Decoupled Helpers

    private func reportStatus(_ text: String) {
        CompanionReportPresenterRegistry.shared?.setIntermediateStatusText(text)
    }

    private func deliverReport(_ text: String, speechNarrative: String?) async {
        await CompanionReportPresenterRegistry.shared?.speakAndReportText(text, speechNarrative: speechNarrative)
    }
}
