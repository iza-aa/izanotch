//
//  FuturesScoutCoreAnalyst.swift
//  izaNotch
//
//  Pure Deterministic Mathematical Core for On-Demand Chart Analyst (Option B Canon)
//  Architecture Decoupling (Agent 1 & 2 Specification):
//  Zero AppKit, Zero UI, Zero CUA dependencies — 100% unit-testable.
//

import Foundation

// MARK: - 1. Fibonacci Time Window (Anti Off-by-One Specification)

/// Models the Fibonacci Time Zone dimension based on W.D. Gann / Astronacci "Price Meets Time" canon.
///
/// Anti Off-by-One Convention (Auditor Specification):
/// - Anchor: Index of confirmed dominant swing pivot bar in `closedM15` (count = 0).
/// - Current Count: `currentClosedIdx - pivotIdx` (evaluated exclusively on confirmed `isClosed: true` bars).
/// - Target Fib Series: F ∈ {8, 13, 21, 34} bars on M15 timeframe.
/// - Invariant: Time Dimension is strictly PRESENTATIONAL (never vetoes or downgrades signals).
public struct FibonacciTimeWindow: Equatable, Sendable {
    public enum State: String, Equatable, Sendable {
        case inWindow = "IN_WINDOW"
        case approaching = "APPROACHING"
        case windowPassed = "WINDOW_PASSED"
        case noAnchor = "NO_ANCHOR"
    }

    public let state: State
    public let anchorIndex: Int?
    public let currentBarCount: Int
    public let currentTargetFib: Int
    public let barsRemaining: Int
    public let displayText: String
    public let estimatedTargetDate: Date?

    public init(
        state: State,
        anchorIndex: Int?,
        currentBarCount: Int,
        currentTargetFib: Int,
        barsRemaining: Int,
        displayText: String,
        estimatedTargetDate: Date? = nil
    ) {
        self.state = state
        self.anchorIndex = anchorIndex
        self.currentBarCount = currentBarCount
        self.currentTargetFib = currentTargetFib
        self.barsRemaining = barsRemaining
        self.displayText = displayText
        self.estimatedTargetDate = estimatedTargetDate
    }
}

// MARK: - 2. Analysis Result Models

public typealias MarketSession = FuturesScoutCoreAnalyst.MarketSession

public enum FuturesScoutAnalysisError: Error, Equatable, Sendable {
    case insufficientData(h1Count: Int, m15Count: Int, m5Count: Int)
}

public struct FuturesScoutAnalysisResult: Equatable, Sendable {
    public let symbol: String
    public let tvSymbol: String
    public let exchangeSymbol: String
    public let currentLivePrice: Double
    public let referenceDate: Date

    // Multi-Timeframe ATR
    public let atrM15: Double
    public let atrM5: Double

    // H1 Compass
    public let regimeResult: AstronacciH1RegimeResult
    public var regime: AstronacciRegime { regimeResult.regime }

    // M15 Roadmap Structure
    public let swingLow: Double
    public let swingHigh: Double
    public let swingRange: Double
    public let hasValidSwing: Bool
    public let gpLow: Double
    public let gpHigh: Double
    public let invalidationLevel: Double
    public let targetReTest: Double
    public let targetExpansion1272: Double
    public let targetExpansion1618: Double

    // M5 Trigger & Oscillator
    public let candleTrigger: AstronacciCandleTrigger
    public let stochM5K: Double
    public let stochM5D: Double
    public let isStochM5OversoldCross: Bool
    public let isStochM5OverboughtCross: Bool

    // M15 Context Oscillator
    public let stochM15K: Double
    public let stochM15D: Double

    // Time Dimension (Presentational Only)
    public let marketSession: MarketSession
    public let fibTimeWindow: FibonacciTimeWindow

    // Task 1: Key Reversal Zone / Fibonacci Cluster Confluence (Presentational Only)
    public let fibCluster: FibonacciClusterResult

    // Task 2: Structural Mathematical Divergence (Presentational Only)
    public let divergence: AstronacciDivergenceResult

    // Task 3: Quasimodo (QM / Over-Under) Pattern (Presentational Only)
    public let quasimodo: AstronacciQMResult

    // Task 5: Financial Astrology & Planetary Ephemeris (Presentational Only)
    public let astroReport: AstronacciAstroReport

    // Task 6: High-Impact Macro Economic News Buffer (Presentational & Advisory Only)
    public let newsBuffer: NewsBufferResult

    // Task 7: Planetary Aspects & Zodiac Ingress (Presentational & Advisory Only)
    public let planetaryAspects: PlanetaryAspectReport

    // First-Class Status
    public enum Status: String, Equatable, Sendable {
        case standAsideChoppy = "STAND ASIDE (Pasar Choppy / Belum Ada Ayunan Dominan)"
        case standAsideOutsideGP = "STAND ASIDE (Di Luar Golden Pocket)"
        case inGoldenPocketWaiting = "DALAM PANTAUAN (Harga di Golden Pocket, Menunggu Kandel/Stoch)"
        case setupDetected = "SETUP TERPANTAU (Di Golden Pocket + Konfirmasi Reversal / Momentum)"
    }
    public let status: Status
    public let isInGP: Bool

    public init(
        symbol: String,
        tvSymbol: String,
        exchangeSymbol: String,
        currentLivePrice: Double,
        referenceDate: Date,
        atrM15: Double,
        atrM5: Double,
        regimeResult: AstronacciH1RegimeResult,
        swingLow: Double,
        swingHigh: Double,
        swingRange: Double,
        hasValidSwing: Bool,
        gpLow: Double,
        gpHigh: Double,
        invalidationLevel: Double,
        targetReTest: Double,
        targetExpansion1272: Double,
        targetExpansion1618: Double,
        candleTrigger: AstronacciCandleTrigger,
        stochM5K: Double,
        stochM5D: Double,
        isStochM5OversoldCross: Bool,
        isStochM5OverboughtCross: Bool,
        stochM15K: Double,
        stochM15D: Double,
        marketSession: MarketSession,
        fibTimeWindow: FibonacciTimeWindow,
        status: Status,
        isInGP: Bool,
        fibCluster: FibonacciClusterResult = .empty,
        divergence: AstronacciDivergenceResult = .none,
        quasimodo: AstronacciQMResult = .none,
        astroReport: AstronacciAstroReport = .standard,
        newsBuffer: NewsBufferResult = .clear,
        planetaryAspects: PlanetaryAspectReport = .standard
    ) {
        self.symbol = symbol
        self.tvSymbol = tvSymbol
        self.exchangeSymbol = exchangeSymbol
        self.currentLivePrice = currentLivePrice
        self.referenceDate = referenceDate
        self.atrM15 = atrM15
        self.atrM5 = atrM5
        self.regimeResult = regimeResult
        self.swingLow = swingLow
        self.swingHigh = swingHigh
        self.swingRange = swingRange
        self.hasValidSwing = hasValidSwing
        self.gpLow = gpLow
        self.gpHigh = gpHigh
        self.invalidationLevel = invalidationLevel
        self.targetReTest = targetReTest
        self.targetExpansion1272 = targetExpansion1272
        self.targetExpansion1618 = targetExpansion1618
        self.candleTrigger = candleTrigger
        self.stochM5K = stochM5K
        self.stochM5D = stochM5D
        self.isStochM5OversoldCross = isStochM5OversoldCross
        self.isStochM5OverboughtCross = isStochM5OverboughtCross
        self.stochM15K = stochM15K
        self.stochM15D = stochM15D
        self.marketSession = marketSession
        self.fibTimeWindow = fibTimeWindow
        self.status = status
        self.isInGP = isInGP
        self.fibCluster = fibCluster
        self.divergence = divergence
        self.quasimodo = quasimodo
        self.astroReport = astroReport
        self.newsBuffer = newsBuffer
        self.planetaryAspects = planetaryAspects
    }

    public static func == (lhs: FuturesScoutAnalysisResult, rhs: FuturesScoutAnalysisResult) -> Bool {
        return lhs.symbol == rhs.symbol &&
            lhs.currentLivePrice == rhs.currentLivePrice &&
            lhs.regime == rhs.regime &&
            lhs.swingLow == rhs.swingLow &&
            lhs.swingHigh == rhs.swingHigh &&
            lhs.gpLow == rhs.gpLow &&
            lhs.gpHigh == rhs.gpHigh &&
            lhs.invalidationLevel == rhs.invalidationLevel &&
            lhs.status == rhs.status &&
            lhs.fibTimeWindow == rhs.fibTimeWindow &&
            lhs.marketSession == rhs.marketSession &&
            lhs.newsBuffer == rhs.newsBuffer &&
            lhs.planetaryAspects == rhs.planetaryAspects
    }
}

// MARK: - 3. Multi-Market Radar & Candidate Models

public enum MarketCandidateClassification: String, Equatable, Sendable {
    case hot = "Hot (Setup A-Grade)"
    case approaching = "Approaching (Mendekati GP)"
    case deadOrChoppy = "Choppy / Dead (Flat)"
    case dataUnavailable = "Data Unavailable"
}

public struct MarketCandidateEvaluation: Equatable, Sendable {
    public let symbol: String
    public let displaySymbol: String
    public let classification: MarketCandidateClassification
    public let analysisResult: FuturesScoutAnalysisResult?
    public let distanceToGPAtrMultiple: Double?
    public let failureReason: String?

    public init(
        symbol: String,
        displaySymbol: String,
        classification: MarketCandidateClassification,
        analysisResult: FuturesScoutAnalysisResult? = nil,
        distanceToGPAtrMultiple: Double? = nil,
        failureReason: String? = nil
    ) {
        self.symbol = symbol
        self.displaySymbol = displaySymbol
        self.classification = classification
        self.analysisResult = analysisResult
        self.distanceToGPAtrMultiple = distanceToGPAtrMultiple
        self.failureReason = failureReason
    }
}

// MARK: - 4. Pure Deterministic Mathematical Core (FuturesScoutCoreAnalyst)

public struct FuturesScoutCoreAnalyst {
    public enum MarketSession: String, Sendable, Equatable {
        case london = "LONDON"
        case newYork = "NEW_YORK"
        case londonNYOverlap = "LONDON_NY_OVERLAP"
        case asianOffPeak = "ASIAN_OFF_PEAK"
    }

    public static let activeFibTargets = [8, 13, 21, 34]

    /// Evaluates technical market geometry, regime, time dimension, and oscillators.
    /// Pure function: Zero AppKit, Zero CUA, Zero UI — completely deterministic and testable.
    public static func analyze(
        rawSymbol: String,
        klinesH1: [AstronacciKline],
        klinesM15: [AstronacciKline],
        klinesM5: [AstronacciKline],
        referenceDate: Date = Date(),
        engine: AstronacciDeterministicEngine = .shared
    ) -> Result<FuturesScoutAnalysisResult, FuturesScoutAnalysisError> {
        let exchangeSymbol = FuturesScoutMarketDataService.normalizeSymbolForExchange(rawSymbol)
        let tvSymbol = FuturesScoutMarketDataService.normalizeSymbolForTradingView(rawSymbol)
        let displaySymbol = exchangeSymbol.replacingOccurrences(of: "-", with: "/")

        // Strict Anti-Repaint Filtering: Only evaluate confirmed closed bars
        let closedH1 = klinesH1.filter { $0.isClosed && $0.isValid }
        let closedM15 = klinesM15.filter { $0.isClosed && $0.isValid }
        let closedM5 = klinesM5.filter { $0.isClosed && $0.isValid }

        guard closedH1.count >= 20, closedM15.count >= 10, closedM5.count >= 2 else {
            return .failure(.insufficientData(h1Count: closedH1.count, m15Count: closedM15.count, m5Count: closedM5.count))
        }

        let currentLivePrice = klinesM5.last?.close ?? closedM5.last?.close ?? 0.0
        let lastClosedM5 = closedM5[closedM5.count - 1]
        let prevClosedM5 = closedM5[closedM5.count - 2]

        // ATR Canon: M15 ATR for structure & invalidation; M5 ATR for candle trigger
        let atrM15 = engine.calculateATR(period: 14, klines: closedM15)
        let atrM5 = engine.calculateATR(period: 14, klines: closedM5)

        // A. Canonical H1 Trend Regime (EMA 21, 34, 200 - Single Source of Truth)
        let regimeResult = engine.detectH1Regime(klinesH1: klinesH1)
        let regime = regimeResult.regime
        let isBullish = (regime == .bullish)
        let isBearish = (regime == .bearish)

        // B. Swing Structure on M15 (Lookback 48, minAtrMultiple 3.0)
        let dominantSwing = engine.detectDominantImpulsiveSwing(
            klines: closedM15,
            atr: atrM15,
            lookbackBars: min(48, closedM15.count),
            minAtrMultiple: 3.0
        )
        let pivotFractals = engine.detect5BarPivotFractals(klines: closedM15)

        let swingLow: Double
        let swingHigh: Double
        let anchorIdx: Int?
        let hasValidSwing: Bool

        if let dom = dominantSwing {
            swingLow = dom.swingLow
            swingHigh = dom.swingHigh
            anchorIdx = isBullish ? dom.highIndex : (isBearish ? dom.lowIndex : max(dom.lowIndex, dom.highIndex))
            hasValidSwing = true
        } else if let piv = pivotFractals {
            swingLow = piv.swingLow
            swingHigh = piv.swingHigh
            anchorIdx = isBullish ? piv.highIndex : (isBearish ? piv.lowIndex : max(piv.lowIndex, piv.highIndex))
            hasValidSwing = true
        } else {
            swingLow = closedM15.map(\.low).min() ?? (currentLivePrice * 0.98)
            swingHigh = closedM15.map(\.high).max() ?? (currentLivePrice * 1.02)
            anchorIdx = nil
            hasValidSwing = false
        }

        let rawRange = max(0.0, swingHigh - swingLow)
        let minRange = max(currentLivePrice * 0.0005, 0.000001)
        let swingRange = max(rawRange, minRange)

        // P0 Canon: Fail-Closed on Degenerate Range (< 0.05% of price or 0)
        let isDegenerateSwing = rawRange < minRange
        let effectivelyValidSwing = hasValidSwing && !isDegenerateSwing

        // Calculate Fibonacci Golden Pocket (0.500 to 0.618), Invalidation (78.6%), and Expansion (1.272 / 1.618)
        let gpLow: Double
        let gpHigh: Double
        let invalidationLevel: Double
        let targetReTest: Double
        let targetExp1272: Double
        let targetExp1618: Double

        if isBullish {
            // Retracement downwards from High
            gpHigh = swingHigh - (swingRange * 0.500)
            gpLow = swingHigh - (swingRange * 0.618)
            invalidationLevel = swingHigh - (swingRange * 0.786)
            targetReTest = swingHigh
            targetExp1272 = swingLow + (swingRange * 1.272)
            targetExp1618 = swingLow + (swingRange * 1.618)
        } else if isBearish {
            // Retracement upwards from Low
            gpLow = swingLow + (swingRange * 0.500)
            gpHigh = swingLow + (swingRange * 0.618)
            invalidationLevel = swingLow + (swingRange * 0.786)
            targetReTest = swingLow
            targetExp1272 = swingHigh - (swingRange * 1.272)
            targetExp1618 = swingHigh - (swingRange * 1.618)
        } else {
            // Symmetrical reference for Choppy
            gpLow = swingLow + (swingRange * 0.382)
            gpHigh = swingLow + (swingRange * 0.618)
            invalidationLevel = swingLow
            targetReTest = swingHigh
            targetExp1272 = swingHigh
            targetExp1618 = swingHigh + (swingRange * 0.618)
        }

        // C. Candlestick Trigger Evaluation on M5 (Strict Anti-Repaint)
        let candleTrigger = engine.detectCandleTrigger(kline: lastClosedM5, previousKline: prevClosedM5, atr: atrM5)

        // D. Single Source of Truth Oscillators via Engine
        let stochM5 = engine.calculateStochastic(kPeriod: 5, dPeriod: 3, slowing: 3, klines: closedM5)
        let stochM15 = engine.calculateStochastic(kPeriod: 14, dPeriod: 3, slowing: 3, klines: closedM15)

        // E. Time Dimension Evaluation (Fibonacci Time Zones on M15 + Market Session)
        let currentClosedM15Idx = closedM15.count - 1
        let timeWindow = evaluateFibonacciTimeWindow(
            anchorIndex: anchorIdx,
            currentClosedIndex: currentClosedM15Idx,
            referenceDate: referenceDate
        )
        let marketSession = getCurrentMarketSession(date: referenceDate)

        // F. First-Class Status Definition (Evaluated on confirmed last closed M5 candle)
        let isInGP = lastClosedM5.close >= min(gpLow, gpHigh) && lastClosedM5.close <= max(gpLow, gpHigh)
        let hasTriggerConfirmation: Bool
        if isBullish {
            hasTriggerConfirmation = candleTrigger.isBullish || stochM5.isGoldenCrossInOversold
        } else if isBearish {
            hasTriggerConfirmation = candleTrigger.isBearish || stochM5.isDeadCrossInOverbought
        } else {
            hasTriggerConfirmation = false
        }

        let status: FuturesScoutAnalysisResult.Status
        if !effectivelyValidSwing || (!isBullish && !isBearish) {
            status = .standAsideChoppy
        } else if isInGP && hasTriggerConfirmation {
            status = .setupDetected
        } else if isInGP {
            status = .inGoldenPocketWaiting
        } else {
            status = .standAsideOutsideGP
        }

        // G. Fibonacci Cluster Confluence (Task 1 Canon - Pure Analyst Layer)
        let fibCluster = AstronacciClusterEngine.evaluateConfluence(
            klinesH1: closedH1,
            klinesM15: closedM15,
            atr14M15: atrM15,
            regime: regime
        )

        // H. Structural Mathematical Divergence (Task 2 Canon - Pure Analyst Layer)
        let divergence = AstronacciDivergenceEngine().detectDivergence(klines: closedM15)

        // I. Quasimodo Pattern Recognition (Task 3 Canon - Pure Analyst Layer)
        let quasimodo = AstronacciQuasimodoEngine().detectQuasimodo(
            klines: closedM15,
            currentPrice: currentLivePrice,
            atr: atrM15
        )

        // J. Financial Astrology & Planetary Ephemeris (Task 5 Canon - Pure Analyst Layer)
        let astroReport = AstronacciEphemerisEngine().calculateAstroReport(date: referenceDate)

        // K. High-Impact Economic News Buffer (SOP Bab 7: 45 min buffer - Pure Analyst Layer)
        let newsBuffer = AstronacciEconomicCalendarEngine().evaluateBuffer(currentDate: referenceDate)

        // L. Planetary Aspects & Zodiac Ingress (Eye of Future Geometry - Pure Analyst Layer)
        let planetaryAspects = AstronacciPlanetaryAspectEngine().evaluateAspectReport(date: referenceDate)

        let result = FuturesScoutAnalysisResult(
            symbol: displaySymbol,
            tvSymbol: tvSymbol,
            exchangeSymbol: exchangeSymbol,
            currentLivePrice: currentLivePrice,
            referenceDate: referenceDate,
            atrM15: atrM15,
            atrM5: atrM5,
            regimeResult: regimeResult,
            swingLow: swingLow,
            swingHigh: swingHigh,
            swingRange: swingRange,
            hasValidSwing: effectivelyValidSwing,
            gpLow: gpLow,
            gpHigh: gpHigh,
            invalidationLevel: invalidationLevel,
            targetReTest: targetReTest,
            targetExpansion1272: targetExp1272,
            targetExpansion1618: targetExp1618,
            candleTrigger: candleTrigger,
            stochM5K: stochM5.k,
            stochM5D: stochM5.d,
            isStochM5OversoldCross: stochM5.isGoldenCrossInOversold,
            isStochM5OverboughtCross: stochM5.isDeadCrossInOverbought,
            stochM15K: stochM15.k,
            stochM15D: stochM15.d,
            marketSession: marketSession,
            fibTimeWindow: timeWindow,
            status: status,
            isInGP: isInGP,
            fibCluster: fibCluster,
            divergence: divergence,
            quasimodo: quasimodo,
            astroReport: astroReport,
            newsBuffer: newsBuffer,
            planetaryAspects: planetaryAspects
        )

        return .success(result)
    }

    /// Evaluates the confirmed M15 Fibonacci Time Window without off-by-one errors.
    public static func evaluateFibonacciTimeWindow(
        anchorIndex: Int?,
        currentClosedIndex: Int,
        referenceDate: Date? = nil,
        barIntervalSeconds: TimeInterval = 900
    ) -> FibonacciTimeWindow {
        guard let anchor = anchorIndex, anchor >= 0, anchor <= currentClosedIndex else {
            return FibonacciTimeWindow(
                state: .noAnchor,
                anchorIndex: nil,
                currentBarCount: 0,
                currentTargetFib: 0,
                barsRemaining: 0,
                displayText: "Belum ada anchor ayunan dominan",
                estimatedTargetDate: nil
            )
        }

        let count = currentClosedIndex - anchor
        if count > 34 {
            return FibonacciTimeWindow(
                state: .windowPassed,
                anchorIndex: anchor,
                currentBarCount: count,
                currentTargetFib: 34,
                barsRemaining: 0,
                displayText: "Jendela waktu Fibonacci telah terlewati (\(count) bar M15 > 34)",
                estimatedTargetDate: nil
            )
        } else if let exact = activeFibTargets.first(where: { $0 == count }) {
            return FibonacciTimeWindow(
                state: .inWindow,
                anchorIndex: anchor,
                currentBarCount: count,
                currentTargetFib: exact,
                barsRemaining: 0,
                displayText: "Tepat di Jendela Fibonacci (\(exact) bar M15)",
                estimatedTargetDate: referenceDate
            )
        } else if let next = activeFibTargets.first(where: { $0 > count }) {
            let remaining = next - count
            let targetDate = referenceDate?.addingTimeInterval(Double(remaining) * barIntervalSeconds)
            let etaStr: String
            if let td = targetDate {
                let f = DateFormatter()
                f.dateFormat = "HH:mm 'UTC'"
                f.timeZone = TimeZone(secondsFromGMT: 0)
                etaStr = " • est. \(f.string(from: td)) (proyeksi nominal kandel, bukan jadwal pasti)"
            } else {
                etaStr = ""
            }
            return FibonacciTimeWindow(
                state: .approaching,
                anchorIndex: anchor,
                currentBarCount: count,
                currentTargetFib: next,
                barsRemaining: remaining,
                displayText: "Jendela Fibonacci berikutnya: \(remaining) kandel lagi (Fib \(next) bar M15\(etaStr))",
                estimatedTargetDate: targetDate
            )
        } else {
            return FibonacciTimeWindow(
                state: .windowPassed,
                anchorIndex: anchor,
                currentBarCount: count,
                currentTargetFib: 34,
                barsRemaining: 0,
                displayText: "Jendela waktu Fibonacci telah terlewati",
                estimatedTargetDate: nil
            )
        }
    }

    /// Evaluates current global market session with resilient dynamic TZDB (DST-free).
    public static func getCurrentMarketSession(date: Date = Date()) -> MarketSession {
        var londonCal = Calendar(identifier: .gregorian)
        londonCal.timeZone = TimeZone(identifier: "Europe/London") ?? .current
        let londonHour = Double(londonCal.component(.hour, from: date)) + Double(londonCal.component(.minute, from: date)) / 60.0
        let isLondonOpen = londonHour >= 8.0 && londonHour < 16.5

        var nyCal = Calendar(identifier: .gregorian)
        nyCal.timeZone = TimeZone(identifier: "America/New_York") ?? .current
        let nyHour = Double(nyCal.component(.hour, from: date)) + Double(nyCal.component(.minute, from: date)) / 60.0
        let isNYOpen = nyHour >= 9.5 && nyHour < 16.0

        if isLondonOpen && isNYOpen {
            return .londonNYOverlap
        } else if isLondonOpen {
            return .london
        } else if isNYOpen {
            return .newYork
        } else {
            return .asianOffPeak
        }
    }

    /// Formats prices dynamically based on asset magnitude.
    /// Preserves precision for sub-dollar altcoins (e.g. ASTER $0.7412, PEPE $0.000012)
    /// while keeping clean decimals for large-cap assets (BTC $84012.3, ETH $2450.50).
    public static func formatPrice(_ price: Double) -> String {
        let absVal = abs(price)
        if absVal >= 1000.0 {
            return String(format: "%.1f", price)
        } else if absVal >= 1.0 {
            return String(format: "%.2f", price)
        } else if absVal >= 0.01 {
            return String(format: "%.4f", price)
        } else if absVal >= 0.0001 {
            return String(format: "%.6f", price)
        } else {
            return String(format: "%.8f", price)
        }
    }

    /// Renders dual-payload outputs:
    /// 1. `cardMarkdown`: Formatted Executive Briefing Card for Home Space Chat.
    /// 2. `voiceNarrative`: 100% clean plain-text human speech for TTS (<300 chars, ZERO markdown characters).
    public static func renderPresentation(result: FuturesScoutAnalysisResult) -> (cardMarkdown: String, voiceNarrative: String) {
        let coin = result.symbol.components(separatedBy: "/").first ?? result.symbol
        let minGP = min(result.gpLow, result.gpHigh)
        let maxGP = max(result.gpLow, result.gpHigh)

        // 1. Build Clean Voice Narrative (Auditor Contract: <300 chars, NO markdown syntax)
        let voiceNarrative: String
        if result.newsBuffer.isInsideBuffer, let event = result.newsBuffer.activeEvent {
            let cleanEventName = event.name.replacingOccurrences(of: "(", with: "").replacingOccurrences(of: ")", with: "")
            voiceNarrative = "Perhatian, rilis berita ekonomi besar \(cleanEventName) terpantau dalam rentang empat puluh lima menit. Disarankan Stand Aside untuk menghindari volatilitas ekstrim."
        } else {
            switch result.status {
            case .standAsideChoppy:
                voiceNarrative = "Kondisi pasar \(coin) saat ini sedang konsolidasi di timeframe satu jam. Status teknikal Stand Aside, disarankan menunggu struktur ayunan yang lebih jelas."
            case .setupDetected:
                let invStr = abs(result.invalidationLevel) >= 1.0 ? "\(Int(result.invalidationLevel))" : formatPrice(result.invalidationLevel)
                voiceNarrative = "Setup teknikal terpantau untuk \(coin). Harga berada di area Golden Pocket dengan konfirmasi kandel pembalikan arah. Batas risiko invalidasi di \(invStr) dolar."
            case .inGoldenPocketWaiting:
                let gpLowStr = abs(minGP) >= 1.0 ? "\(Int(minGP))" : formatPrice(minGP)
                let gpHighStr = abs(maxGP) >= 1.0 ? "\(Int(maxGP))" : formatPrice(maxGP)
                voiceNarrative = "\(coin) sedang berada di area Golden Pocket \(gpLowStr) sampai \(gpHighStr) dolar. Kondisi saat ini dalam pantauan menunggu konfirmasi kandel dan momentum."
            case .standAsideOutsideGP:
                let trendWord = result.regime == .bullish ? "naik" : (result.regime == .bearish ? "turun" : "mendatar")
                voiceNarrative = "Rezim tren \(coin) terpantau \(trendWord), namun harga saat ini berada di luar area Golden Pocket. Disarankan menunggu koreksi sehat ke area diskon."
            }
        }

        // 2. Build Executive Briefing Card (Markdown for Chat UI)
        let regimeStr: String
        let regimeColor: String
        switch result.regime {
        case .bullish:
            regimeStr = "BULLISH (Uptrend)"
            regimeColor = "🟢"
        case .bearish:
            regimeStr = "BEARISH (Downtrend)"
            regimeColor = "🔴"
        case .choppy:
            regimeStr = "CHOPPY (Konsolidasi)"
            regimeColor = "⚪"
        }

        let sessionStr: String
        switch result.marketSession {
        case .londonNYOverlap: sessionStr = "London & New York Overlap (Puncak Volatilitas)"
        case .london: sessionStr = "London Session (Ekspansi Tren)"
        case .newYork: sessionStr = "New York Session (Likuiditas Tinggi)"
        case .asianOffPeak: sessionStr = "Asian / Off-Peak (Konsolidasi Rendah)"
        }

        let candleStr: String
        switch result.candleTrigger {
        case .bullishPinBar: candleStr = "Bullish Pin Bar (Reversal Ekor Bawah)"
        case .bullishEngulfing: candleStr = "Bullish Engulfing (Reversal Kuat)"
        case .bearishShootingStar: candleStr = "Bearish Shooting Star (Rejection Atas)"
        case .bearishEngulfing: candleStr = "Bearish Engulfing (Reversal Turun)"
        case .none: candleStr = "Kandel Netral (Belum Ada Pola Reversal)"
        }

        let statusIcon: String
        switch result.status {
        case .standAsideChoppy: statusIcon = "⚪"
        case .standAsideOutsideGP: statusIcon = "⏸️"
        case .inGoldenPocketWaiting: statusIcon = "👀"
        case .setupDetected: statusIcon = "🎯"
        }

        let isActionable = result.status == .setupDetected || result.status == .inGoldenPocketWaiting
        let tpString: String
        let overlayNote: String
        if isActionable {
            tpString = "TP1 (1.272) $\(formatPrice(result.targetExpansion1272)) • TP2 (1.618) $\(formatPrice(result.targetExpansion1618))"
            overlayNote = "Aktif & dipetakan di TradingView"
        } else if result.status == .standAsideOutsideGP {
            tpString = "— *(Tidak berlaku pada status STAND ASIDE / Di Luar GP)*"
            overlayNote = "Garis Referensi Golden Pocket (50.0% – 61.8%) & Ayunan Dominan dipetakan"
        } else {
            tpString = "— *(Tidak berlaku pada status STAND ASIDE / Pasar Choppy)*"
            overlayNote = "— *(Tidak digambar pada status STAND ASIDE / Pasar Choppy)*"
        }

        let actionableCriteria: String
        switch result.status {
        case .standAsideChoppy:
            actionableCriteria = "\n> 💡 **Kriteria Actionable**: Menunggu rezim tren H1 keluar dari konsolidasi (EMA 21/34/200 sejajar searah) ATAU terbentuk ayunan impulsif terkonfirmasi ≥ 3×ATR M15.\n"
        case .standAsideOutsideGP:
            let side = result.regime == .bullish ? "retrace/diskon menuju Golden Pocket" : "pullback/kenaikan menuju Golden Pocket"
            actionableCriteria = "\n> 💡 **Kriteria Actionable**: Menunggu koreksi sehat (\(side)) dan konfirmasi kandel pembalikan arah M5.\n"
        case .inGoldenPocketWaiting:
            actionableCriteria = "\n> 💡 **Kriteria Actionable**: Menunggu konfirmasi kandel pembalikan arah (Pin Bar / Engulfing) pada M5 dengan Stochastic Golden Cross.\n"
        case .setupDetected:
            actionableCriteria = ""
        }

        let clusterLine: String
        if result.fibCluster.hasCluster {
            clusterLine = "\n- **✨ Key Reversal Zone (KRZ Cluster)**: \(result.fibCluster.label)"
        } else {
            clusterLine = ""
        }

        let divergenceLine: String
        if result.divergence.type != .none {
            divergenceLine = "\n- **📊 Divergensi Struktural**: \(result.divergence.description)"
        } else {
            divergenceLine = ""
        }

        let quasimodoLine: String
        if result.quasimodo.type != .none {
            quasimodoLine = "\n- **🎯 Pola Quasimodo (QM)**: \(result.quasimodo.description)"
        } else {
            quasimodoLine = ""
        }

        let newsBanner: String
        if result.newsBuffer.isInsideBuffer, let event = result.newsBuffer.activeEvent {
            let timingDesc = result.newsBuffer.minutesDelta >= 0 ? "\(result.newsBuffer.minutesDelta) menit lagi" : "\(abs(result.newsBuffer.minutesDelta)) menit lalu"
            newsBanner = "\n> 🚨 **PERINGATAN BUFFER BERITA BESAR (SOP ASTRONACCI)**: Rilis berita **\(event.name)** (\(timingDesc)). Volatilitas ekstrim dapat menembus level teknikal. Status disarankan: **STAND ASIDE** hingga 45 menit pasca rilis.\n"
        } else if result.newsBuffer.isExpiredCalendar {
            newsBanner = "\n> ⚠️ **PERINGATAN KALENDER EKONOMI**: Jadwal kalender berita telah kedaluwarsa. Perbarui file jadwal untuk mengaktifkan buffer berita high-impact.\n"
        } else if let event = result.newsBuffer.activeEvent, result.newsBuffer.minutesDelta > 0 && result.newsBuffer.minutesDelta <= 240 {
            let hours = result.newsBuffer.minutesDelta / 60
            let mins = result.newsBuffer.minutesDelta % 60
            let timeStr = hours > 0 ? "\(hours) jam \(mins) menit lagi" : "\(mins) menit lagi"
            newsBanner = "\n> ⏱️ **AGENDA BERITA MENDATANG**: **\(event.name)** dijadwalkan dalam \(timeStr). Waspadai lonjakan volatilitas.\n"
        } else {
            newsBanner = ""
        }

        let aspectLine: String
        if result.planetaryAspects.topAspects.isEmpty {
            aspectLine = ""
        } else {
            let aspectItems = result.planetaryAspects.topAspects.map { $0.description }.joined(separator: "; ")
            aspectLine = "\n- **Aspek Geometri Planet (Eye of Future)**: \(aspectItems) *(Konteks geometri astrologi — interpretasi Eye of Future, bukan sinyal pasti)*"
        }

        let ingressLine: String
        if !result.planetaryAspects.activeIngress.isEmpty {
            let ingressItems = result.planetaryAspects.activeIngress.map { $0.description }.joined(separator: "; ")
            let hasMoon = result.planetaryAspects.activeIngress.contains(where: { $0.body == .moon })
            let moonCaveat = hasMoon ? " *(Perkiraan timing ±2 jam untuk Bulan karena kecepatan orbit ~13°/hari)*" : ""
            ingressLine = "\n- **Zodiac Ingress**: \(ingressItems)\(moonCaveat)"
        } else {
            ingressLine = ""
        }

        let cardMarkdown = """
        ### 📊 Analisis Teknikal: \(result.symbol)
        *Perpetual Futures (BingX) • Timeframe: H1 (Rezim) • M15 (Struktur) • M5 (Trigger)*\(newsBanner)
        **Status**: \(statusIcon) **\(result.status.rawValue)**

        ---

        ### 🧭 Skenario Pasar & Struktur
        Rezim tren H1 teridentifikasi \(regimeColor) **\(regimeStr)**. Rentang ayunan M15 membentang dari $\(formatPrice(result.swingLow)) hingga $\(formatPrice(result.swingHigh)) (lebar $\(formatPrice(result.swingRange))).\(quasimodoLine)

        ### 📐 Peta Level Kunci (Astronacci-Fibonacci)
        - **Harga Terakhir (Live)**: $\(formatPrice(result.currentLivePrice)) USDT
        - **Golden Pocket (50.0% – 61.8%)**: **$\(formatPrice(minGP)) — $\(formatPrice(maxGP))**\(clusterLine)
        - **Level Invalidasi Fibonacci (78.6%)**: **$\(formatPrice(result.invalidationLevel))** • *Batas Struktur Terakhir (\(result.regime == .bullish ? "Swing Low" : "Swing High"))*: $\(formatPrice(result.regime == .bullish ? result.swingLow : result.swingHigh))
        - **Target Proyeksi Ekspansi**: \(tpString)
        - **Overlay Chart**: \(overlayNote)

        ### ⏳ Dimensi Waktu & Momentum (Price Meets Time)
        - **Sesi Pasar**: 🌐 \(sessionStr)
        - **Jendela Kandel Fibonacci**: ⏱️ \(result.fibTimeWindow.displayText)
        - **Siklus Astrologi (Ephemeris)**: \(result.astroReport.description)\(aspectLine)\(ingressLine)
        - **Momentum M15**: Stochastic(14,3,3) K: \(String(format: "%.1f", result.stochM15K)), D: \(String(format: "%.1f", result.stochM15D))\(divergenceLine)
        - **Pemicu Kandel M5**: \(candleStr) • Stoch(5,3,3) K: \(String(format: "%.1f", result.stochM5K))
        \(actionableCriteria)
        > ⚠️ **Catatan Edukasi**: Analisis teknikal objektif berbasis metodologi Astronacci-Fibonacci. Disediakan sebagai panduan pembacaan struktur pasar untuk keputusan trading mandiri Anda, bukan sinyal otomatis atau rekomendasi finansial.
        """

        return (cardMarkdown, voiceNarrative)
    }

    /// Generates deterministic Pine Script v5 code to overlay calculated Astronacci-Fibonacci levels on TradingView.
    /// Plots exact mathematical prices without blind pixel-drag guesses.
    /// Expanded with Option A Dynamic Trade Plan Box (Green Reward Box, Red Risk Box, Blue Entry Limit Line & Labels).
    public static func generatePineScriptOverlay(result: FuturesScoutAnalysisResult) -> String {
        // Choppy market: ZERO canvas mutations
        if result.status == .standAsideChoppy {
            return ""
        }

        let isLong = result.regimeResult.regime == .bullish
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
        if absLive >= 1.0 {
            formatPattern = "#.##"
        } else if absLive >= 0.01 {
            formatPattern = "#.####"
        } else {
            formatPattern = "#.######"
        }

        let timeRemaining = result.fibTimeWindow.barsRemaining
        let hasTimeProjection = timeRemaining > 0
        let timeCode: String
        if hasTimeProjection {
            timeCode = """


                // Fibonacci Time Zone Vertical Projection
                line.delete(time_line)
                label.delete(time_lbl)
                time_line := line.new(x1=bar_index + \(timeRemaining), y1=gp_low, x2=bar_index + \(timeRemaining), y2=gp_high, extend=extend.both, color=color.new(color.purple, 40), width=1, style=line.style_dashed)
                time_lbl := label.new(x=bar_index + \(timeRemaining), y=gp_high, text="Fib Time (\(result.fibTimeWindow.currentTargetFib) Bar)", color=color.new(color.purple, 20), textcolor=color.white, style=label.style_label_down, size=size.tiny)
            """
        } else {
            timeCode = ""
        }

        let hasQM = result.quasimodo.type != .none
        let qmCode: String
        if hasQM {
            qmCode = """


                // Quasimodo Left Shoulder Reference Line
                line.delete(qm_line)
                label.delete(qm_lbl)
                qm_line := line.new(x1=left_bar, y1=\(formatPrice(result.quasimodo.leftShoulderPrice)), x2=right_bar, y2=\(formatPrice(result.quasimodo.leftShoulderPrice)), color=color.new(color.maroon, 30), width=1, style=line.style_dotted)
                qm_lbl := label.new(x=left_bar, y=\(formatPrice(result.quasimodo.leftShoulderPrice)), text="QM LS $\(formatPrice(result.quasimodo.leftShoulderPrice))", color=color.new(color.maroon, 20), textcolor=color.white, style=label.style_label_right, size=size.tiny)
            """
        } else {
            qmCode = ""
        }

        let statusBadge = result.status == .setupDetected ? "SETUP DETECTED" : (result.isInGP ? "IN GOLDEN POCKET" : "STAND ASIDE")
        let biasBadge = isLong ? "BUY / LONG" : "SELL / SHORT"
        let statusColor = result.status == .setupDetected ? "color.green" : (result.isInGP ? "color.orange" : "color.gray")
        let divLabel = result.divergence.type != .none ? (result.divergence.isBullish ? "Bullish Div" : "Bearish Div") : "None"
        let newsText = result.newsBuffer.isInsideBuffer ? "⚠️ BUFFER BERITA AKTIF" : "Normal"

        let hudTableCode = """


                // 5. Pine Script Dashboard Table HUD (Top-Right)
                table.cell(hud, 0, 0, "STATUS & BIAS", bgcolor=color.new(color.black, 45), text_color=color.white, text_size=size.tiny)
                table.cell(hud, 1, 0, "\(statusBadge) (\(biasBadge))", bgcolor=color.new(\(statusColor), 30), text_color=color.white, text_size=size.tiny)
                table.cell(hud, 0, 1, "ENTRY LIMIT", bgcolor=color.new(color.black, 45), text_color=color.white, text_size=size.tiny)
                table.cell(hud, 1, 1, "$\(formatPrice(entryLimit)) (GP)", bgcolor=color.new(color.blue, 70), text_color=color.aqua, text_size=size.tiny)
                table.cell(hud, 0, 2, "TAKE PROFIT", bgcolor=color.new(color.black, 45), text_color=color.white, text_size=size.tiny)
                table.cell(hud, 1, 2, "TP1: $\(formatPrice(tp1)) | TP2: $\(formatPrice(tp2))", bgcolor=color.new(color.green, 70), text_color=color.green, text_size=size.tiny)
                table.cell(hud, 0, 3, "STOP LOSS", bgcolor=color.new(color.black, 45), text_color=color.white, text_size=size.tiny)
                table.cell(hud, 1, 3, "$\(formatPrice(inv)) (R:R 1:\(String(format: "%.1f", rrRatio)))", bgcolor=color.new(color.red, 70), text_color=color.red, text_size=size.tiny)
                table.cell(hud, 0, 4, "KRZ CLUSTER", bgcolor=color.new(color.black, 45), text_color=color.white, text_size=size.tiny)
                table.cell(hud, 1, 4, "\(result.fibCluster.hasCluster ? "$\(formatPrice(result.fibCluster.krzMax)) - $\(formatPrice(result.fibCluster.krzMin))" : "N/A")", bgcolor=color.new(color.black, 45), text_color=color.purple, text_size=size.tiny)
                table.cell(hud, 0, 5, "DIVERGENCE", bgcolor=color.new(color.black, 45), text_color=color.white, text_size=size.tiny)
                table.cell(hud, 1, 5, "\(divLabel)", bgcolor=color.new(color.black, 45), text_color=color.yellow, text_size=size.tiny)
                table.cell(hud, 0, 6, "BERITA / WAKTU", bgcolor=color.new(color.black, 45), text_color=color.white, text_size=size.tiny)
                table.cell(hud, 1, 6, "\(newsText) | Fib \(result.fibTimeWindow.currentTargetFib) Bar", bgcolor=color.new(color.black, 45), text_color=color.white, text_size=size.tiny)
            """

        // Mode 1: Outside Golden Pocket Reference Context Overlay (P3 Canon)
        // Dotted GP zone + continuous reference lines + status note. Zero risk/reward box mutations.
        if result.status == .standAsideOutsideGP {
            let statusText = isLong ? "STATUS: Menunggu Retrace ke Golden Pocket" : "STATUS: Menunggu Pullback ke Golden Pocket"
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
            var box krz_box = na
            var label status_lbl = na
            var line time_line = na
            var label time_lbl = na
            var line qm_line = na
            var label qm_lbl = na
            var table hud = table.new(position.top_right, 2, 7, bgcolor=color.new(color.black, 25), border_color=color.new(color.gray, 60), border_width=1)

            if barstate.islast
                box.delete(gp_box)
                box.delete(krz_box)
                label.delete(status_lbl)

                int left_bar = bar_index - 8
                int right_bar = bar_index + 16

                gp_box := box.new(left=left_bar, top=gp_high, right=right_bar, bottom=gp_low, bgcolor=color.new(color.orange, 92), border_color=color.new(color.orange, 40), border_style=line.style_dashed)
                \(result.fibCluster.hasCluster ? "krz_box := box.new(left=left_bar, top=\(formatPrice(result.fibCluster.krzMax)), right=right_bar, bottom=\(formatPrice(result.fibCluster.krzMin)), bgcolor=color.new(color.purple, 88), border_color=color.purple, border_style=line.style_dashed)" : "")
                status_lbl := label.new(x=right_bar, y=(gp_high + gp_low) / 2, text="\(statusText) (" + str.tostring(gp_low, "\(formatPattern)") + " - " + str.tostring(gp_high, "\(formatPattern)") + ")", color=color.new(color.orange, 20), textcolor=color.white, style=label.style_label_left, size=size.small)\(timeCode)\(qmCode)\(hudTableCode)
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
        var box krz_box = na
        var line entry_line = na
        var label entry_lbl = na
        var label sl_lbl = na
        var label tp1_lbl = na
        var label tp2_lbl = na
        var label title_lbl = na
        var line time_line = na
        var label time_lbl = na
        var line qm_line = na
        var label qm_lbl = na
        var table hud = table.new(position.top_right, 2, 7, bgcolor=color.new(color.black, 25), border_color=color.new(color.gray, 60), border_width=1)

        if barstate.islast
            // Cleanup prior drawings
            box.delete(tp_box)
            box.delete(sl_box)
            box.delete(gp_box)
            box.delete(krz_box)
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
            \(result.fibCluster.hasCluster ? "krz_box := box.new(left=left_bar, top=\(formatPrice(result.fibCluster.krzMax)), right=right_bar, bottom=\(formatPrice(result.fibCluster.krzMin)), bgcolor=color.new(color.purple, 82), border_color=color.purple, border_width=1, border_style=line.style_dashed)" : "")

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
            sl_lbl := label.new(x=right_bar, y=inv_level, text="[STOP LOSS]: " + str.tostring(inv_level, "\(formatPattern)") + " (Inv 78.6%)", color=color.red, textcolor=color.white, style=label.style_label_left, size=size.small)\(timeCode)\(qmCode)\(hudTableCode)
        """
    }

    // MARK: - Multi-Market Radar Screening & Overview Formatter (Reviewer SSOT Canon)

    /// Evaluates a market candidate strictly using SSOT analysis result.
    /// Reviewer Condition 2:
    /// - Hot = directional regime + in-GP + trigger (matches result.status == .setupDetected)
    /// - Approaching = min(|price - GP|) / ATR <= 1.5 (or in-GP waiting)
    /// - Choppy / Dead = rest (choppy or far outside GP)
    public static func evaluateMarketCandidate(
        rawSymbol: String,
        result: FuturesScoutAnalysisResult
    ) -> MarketCandidateEvaluation {
        let displaySymbol = result.symbol
        let isDirectional = result.regimeResult.regime == .bullish || result.regimeResult.regime == .bearish

        if !isDirectional || result.status == .standAsideChoppy {
            return MarketCandidateEvaluation(
                symbol: rawSymbol,
                displaySymbol: displaySymbol,
                classification: .deadOrChoppy,
                analysisResult: result,
                distanceToGPAtrMultiple: nil,
                failureReason: nil
            )
        }

        let minGP = min(result.gpLow, result.gpHigh)
        let maxGP = max(result.gpLow, result.gpHigh)
        let livePrice = result.currentLivePrice

        let distToBoundary: Double
        if livePrice < minGP {
            distToBoundary = minGP - livePrice
        } else if livePrice > maxGP {
            distToBoundary = livePrice - maxGP
        } else {
            distToBoundary = 0.0
        }

        let atrM15 = max(result.atrM15, 0.000001)
        let atrMultiple = distToBoundary / atrM15

        if result.status == .setupDetected {
            return MarketCandidateEvaluation(
                symbol: rawSymbol,
                displaySymbol: displaySymbol,
                classification: .hot,
                analysisResult: result,
                distanceToGPAtrMultiple: atrMultiple,
                failureReason: nil
            )
        }

        if result.status == .inGoldenPocketWaiting || atrMultiple <= 1.5 {
            return MarketCandidateEvaluation(
                symbol: rawSymbol,
                displaySymbol: displaySymbol,
                classification: .approaching,
                analysisResult: result,
                distanceToGPAtrMultiple: atrMultiple,
                failureReason: nil
            )
        }

        return MarketCandidateEvaluation(
            symbol: rawSymbol,
            displaySymbol: displaySymbol,
            classification: .deadOrChoppy,
            analysisResult: result,
            distanceToGPAtrMultiple: atrMultiple,
            failureReason: nil
        )
    }

    /// Selects deterministic top-pick candidate.
    /// Reviewer Condition 3:
    /// Hot first, tie-break by smallest distance to GP; then Approaching; nil if all choppy/dead.
    public static func selectTopPickCandidate(candidates: [MarketCandidateEvaluation]) -> MarketCandidateEvaluation? {
        let valid = candidates.filter { $0.analysisResult != nil }

        let hotCandidates = valid.filter { $0.classification == .hot }
        if !hotCandidates.isEmpty {
            return hotCandidates.min { a, b in
                let distA = a.distanceToGPAtrMultiple ?? Double.infinity
                let distB = b.distanceToGPAtrMultiple ?? Double.infinity
                return distA < distB
            }
        }

        let approachingCandidates = valid.filter { $0.classification == .approaching }
        if !approachingCandidates.isEmpty {
            return approachingCandidates.min { a, b in
                let distA = a.distanceToGPAtrMultiple ?? Double.infinity
                let distB = b.distanceToGPAtrMultiple ?? Double.infinity
                return distA < distB
            }
        }

        return nil
    }

    /// Synthesizes multi-market radar evaluation into an Executive Market Overview report and clean TTS.
    /// Reviewer Condition 5:
    /// - Satu traceId (handled in caller)
    /// - Skip-bukan-abort
    /// - TTS < 300 char bebas markdown
    /// - Harga via formatPrice
    public static func renderMarketOverview(
        candidates: [MarketCandidateEvaluation],
        referenceDate: Date = Date(),
        topPick: MarketCandidateEvaluation? = nil
    ) -> (cardMarkdown: String, voiceNarrative: String) {
        let session = getCurrentMarketSession(date: referenceDate)
        let sessionStr: String
        switch session {
        case .londonNYOverlap: sessionStr = "London & New York Overlap (Puncak Volatilitas)"
        case .london: sessionStr = "London Session (Ekspansi Tren)"
        case .newYork: sessionStr = "New York Session (Likuiditas Tinggi)"
        case .asianOffPeak: sessionStr = "Asian / Off-Peak (Konsolidasi)"
        }

        let totalCount = candidates.count
        var choppyCount = 0
        var bullishCount = 0
        var bearishCount = 0
        var unavailableCount = 0

        for c in candidates {
            if let res = c.analysisResult {
                switch res.regimeResult.regime {
                case .bullish: bullishCount += 1
                case .bearish: bearishCount += 1
                case .choppy: choppyCount += 1
                }
            } else {
                unavailableCount += 1
            }
        }

        let validCount = max(1, totalCount - unavailableCount)
        let choppyPct = Int(round(Double(choppyCount) / Double(validCount) * 100.0))
        let bullishPct = Int(round(Double(bullishCount) / Double(validCount) * 100.0))
        let bearishPct = Int(round(Double(bearishCount) / Double(validCount) * 100.0))

        let breadthSummary: String
        if choppyPct >= 50 {
            breadthSummary = "Mayoritas pasar (\(choppyPct)%) berada dalam fase konsolidasi/kompresi. Disarankan selektif dan disiplin menunggu konfirmasi breakout."
        } else if bullishPct > bearishPct {
            breadthSummary = "Sentimen dominan Bullish (\(bullishPct)%). Momentum beli relatif lebih unggul di beberapa aset utama."
        } else if bearishPct > bullishPct {
            breadthSummary = "Sentimen dominan Bearish (\(bearishPct)%). Tekanan jual relatif aktif di beberapa aset utama."
        } else {
            breadthSummary = "Kondisi pasar seimbang antara Bullish (\(bullishPct)%) dan Bearish (\(bearishPct)%)."
        }

        var tableRows: [String] = []
        for c in candidates {
            if let res = c.analysisResult {
                let regimeIcon = res.regimeResult.regime == .bullish ? "🟢 Bullish" : (res.regimeResult.regime == .bearish ? "🔴 Bearish" : "⚪ Choppy")
                let statusLabel: String
                switch res.status {
                case .setupDetected: statusLabel = "🎯 Setup A-Grade"
                case .inGoldenPocketWaiting: statusLabel = "👀 In GP (Tunggu M5)"
                case .standAsideOutsideGP: statusLabel = "⏸️ Stand Aside"
                case .standAsideChoppy: statusLabel = "⚪ Stand Aside"
                }

                let distStr: String
                if let mult = c.distanceToGPAtrMultiple {
                    distStr = mult == 0 ? "0.0x (In GP)" : String(format: "%.1fx ATR", mult)
                } else {
                    distStr = "—"
                }

                let stochStr = String(format: "%.1f", res.stochM15K)
                let radarStatus: String
                switch c.classification {
                case .hot: radarStatus = "🟢 **Hot (Tour)**"
                case .approaching: radarStatus = "🟡 Approaching"
                case .deadOrChoppy: radarStatus = "⚪ Skipped (Flat)"
                case .dataUnavailable: radarStatus = "⚠️ Unavailable"
                }

                tableRows.append("| **\(c.displaySymbol)** | \(regimeIcon) | \(statusLabel) | \(distStr) | \(stochStr) | \(radarStatus) |")
            } else {
                tableRows.append("| **\(c.displaySymbol)** | — | ⚠️ Unavailable | — | — | ⚠️ Skipped (Error) |")
            }
        }
        let tableMarkdown = tableRows.joined(separator: "\n")

        let topFocusSection: String
        let voiceNarrative: String

        if let pick = topPick, let res = pick.analysisResult {
            let pickAction = res.status == .setupDetected ? "Setup A-Grade terkonfirmasi dengan pemicu kandel M5 aktif" : "Mendekati area Golden Pocket (\(formatPrice(min(res.gpLow, res.gpHigh))) - \(formatPrice(max(res.gpLow, res.gpHigh))))"
            let minGP = min(res.gpLow, res.gpHigh)
            let maxGP = max(res.gpLow, res.gpHigh)
            let entryLimit = (minGP + maxGP) / 2.0
            let tp1 = res.targetExpansion1272
            let tp2 = res.targetExpansion1618
            let sl = res.invalidationLevel
            let riskDist = abs(entryLimit - sl)
            let rewardDist = abs(tp1 - entryLimit)
            let rrRatio = riskDist > 0 ? (rewardDist / riskDist) : 0.0

            topFocusSection = """
            ### 🎯 Top-Pick Actionable Focus: \(pick.displaySymbol)
            - **Status**: \(pick.classification.rawValue) • **Rezim**: \(res.regimeResult.regime == .bullish ? "Bullish" : "Bearish")
            - **Kondisi**: \(pickAction).
            - **Rencana Trading**:
              - **Entry Limit (GP)**: $\(formatPrice(entryLimit))
              - **Take Profit**: TP1 $\(formatPrice(tp1)) | TP2 $\(formatPrice(tp2))
              - **Stop Loss**: $\(formatPrice(sl)) (R:R 1:\(String(format: "%.1f", rrRatio)))
            - **Status TradingView**: Chart telah diarahkan ke **\(res.tvSymbol)** dengan Pine Script overlay aktif.
            """

            // Clean TTS < 300 char, strictly NO markdown characters (*, #, _, |)
            let pickCoin = pick.symbol.replacingOccurrences(of: "USDT", with: "").uppercased()
            let cleanAction = res.status == .setupDetected ? "setup A-Grade terkonfirmasi" : "mendekati Golden Pocket"
            voiceNarrative = "Pemindaian \(totalCount) pasar selesai. \(pickCoin) menjadi fokus utama karena \(cleanAction). Chart TradingView telah diarahkan ke \(pickCoin)."
        } else {
            topFocusSection = """
            ### 🎯 Top-Pick Actionable Focus
            - **Status**: Seluruh pasar saat ini bergerak Choppy / Flat tanpa setup A-Grade yang terkonfirmasi.
            - **Disiplin SOP**: Sesuai prinsip *Capital Preservation*, chart TradingView dibiarkan bersih (*Zero Mutation*) dan disarankan untuk *Stand Aside*.
            """

            // Clean TTS < 300 char, strictly NO markdown characters (*, #, _, |)
            voiceNarrative = "Pemindaian \(totalCount) pasar selesai. Seluruh pasar saat ini berada dalam kondisi Choppy tanpa tren dominan. Sesuai prinsip disiplin, chart dibiarkan bersih dan disarankan untuk stand aside."
        }

        let cardMarkdown = """
        ### 🌐 Laporan Analisa Pasar Crypto (Multi-Asset Overview)
        *Sesi Pasar: \(sessionStr) • \(totalCount) Pasar Dipindai*

        **Sebaran Rezim Pasar (Market Breadth)**:
        - ⚪ **Choppy / Flat**: \(choppyCount) Pasar (\(choppyPct)%)
        - 🟢 **Bullish**: \(bullishCount) Pasar (\(bullishPct)%)
        - 🔴 **Bearish**: \(bearishCount) Pasar (\(bearishPct)%)
        \(unavailableCount > 0 ? "- ⚠️ **Data Unavailable**: \(unavailableCount) Pasar\n" : "")
        > 💡 \(breadthSummary)

        ---

        ### 📊 Matriks Kondisi Seluruh Pasar
        | Aset | Rezim H1 | Status Setup | Jarak ke GP | Stoch M15 | Status Radar |
        | :--- | :--- | :--- | :--- | :--- | :--- |
        \(tableMarkdown)

        ---

        \(topFocusSection)

        > ⚠️ **Catatan Edukasi**: Analisis teknikal objektif berbasis metodologi Astronacci-Fibonacci. Disediakan sebagai panduan pembacaan struktur pasar untuk keputusan trading mandiri Anda, bukan sinyal otomatis atau rekomendasi finansial.
        """

        return (cardMarkdown, voiceNarrative)
    }
}
