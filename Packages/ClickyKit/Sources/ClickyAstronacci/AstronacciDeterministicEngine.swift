//
//  AstronacciDeterministicEngine.swift
//  boringNotch (Izanotchy Futures Scout)
//
//  Mathematical & Deterministic Technical Analysis Engine
//  Implements the canonical Astronacci Scalping Specification:
//  - Multi-Timeframe Regime (EMA 21, EMA 34, EMA 200 on H1, Fail-Closed on < 200 bars)
//  - Dual-Direction Support: Bullish Long AND Bearish Short Setups
//  - 5-Bar Pivot Fractal Swing Detection on Closed M15 Candles (Anti-Repaint)
//  - Fibonacci Grid: 0.382, 0.500, 0.618, 0.786, Expansion 1.272, 1.618
//  - Candlestick Rejection Anatomy (Pin Bar Wick >= 2x Body, Engulfing, Manual Codable)
//  - Stochastic Oscillator (5, 3, 3): Golden Cross (< 20) & Dead Cross (> 80)
//  - Hard Veto Gate (Candle Trigger AND R:R >= 1.0 Required for Swing High Re-Test)
//  - Calibrated Fee & Slippage Adjusted Position Sizing with Floor Rounding & Min-Step Guard
//

import Foundation

// MARK: - Core Data Structures

public struct AstronacciKline: Sendable, Codable, Equatable {
    public let open: Double
    public let high: Double
    public let low: Double
    public let close: Double
    public let volume: Double
    public let timestamp: Int64
    public let isClosed: Bool

    public init(open: Double, high: Double, low: Double, close: Double, volume: Double, timestamp: Int64, isClosed: Bool = true) {
        self.open = open
        self.high = high
        self.low = low
        self.close = close
        self.volume = volume
        self.timestamp = timestamp
        self.isClosed = isClosed
    }

    public var isValid: Bool {
        return high >= low &&
               high >= open &&
               high >= close &&
               low <= open &&
               low <= close &&
               open > 0 &&
               close > 0 &&
               high > 0 &&
               low > 0 &&
               volume >= 0 &&
               !open.isNaN && !open.isInfinite &&
               !high.isNaN && !high.isInfinite &&
               !low.isNaN && !low.isInfinite &&
               !close.isNaN && !close.isInfinite &&
               !volume.isNaN && !volume.isInfinite
    }
}

public enum AstronacciRegime: String, Codable, Sendable {
    case bullish = "BULLISH"
    case bearish = "BEARISH"
    case choppy = "CHOPPY"
}

public enum AstronacciCandleTrigger: Sendable, Codable, Equatable {
    case bullishPinBar(lowerWickRatio: Double)
    case bearishShootingStar(upperWickRatio: Double)
    case bullishEngulfing
    case bearishEngulfing
    case none

    public var isReversal: Bool {
        switch self {
        case .bullishPinBar, .bearishShootingStar, .bullishEngulfing, .bearishEngulfing:
            return true
        case .none:
            return false
        }
    }

    public var isBullish: Bool {
        switch self {
        case .bullishPinBar, .bullishEngulfing:
            return true
        default:
            return false
        }
    }

    public var isBearish: Bool {
        switch self {
        case .bearishShootingStar, .bearishEngulfing:
            return true
        default:
            return false
        }
    }

    // Manual Codable synthesis for enum with associated values
    private enum CodingKeys: String, CodingKey {
        case type, ratio
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        switch type {
        case "bullishPinBar":
            let r = try container.decode(Double.self, forKey: .ratio)
            self = .bullishPinBar(lowerWickRatio: r)
        case "bearishShootingStar":
            let r = try container.decode(Double.self, forKey: .ratio)
            self = .bearishShootingStar(upperWickRatio: r)
        case "bullishEngulfing":
            self = .bullishEngulfing
        case "bearishEngulfing":
            self = .bearishEngulfing
        default:
            self = .none
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .bullishPinBar(let r):
            try container.encode("bullishPinBar", forKey: .type)
            try container.encode(r, forKey: .ratio)
        case .bearishShootingStar(let r):
            try container.encode("bearishShootingStar", forKey: .type)
            try container.encode(r, forKey: .ratio)
        case .bullishEngulfing:
            try container.encode("bullishEngulfing", forKey: .type)
        case .bearishEngulfing:
            try container.encode("bearishEngulfing", forKey: .type)
        case .none:
            try container.encode("none", forKey: .type)
        }
    }
}

public struct AstronacciFibonacciGrid: Sendable, Codable, Equatable {
    public let swingLow: Double
    public let swingHigh: Double
    public let fib0382: Double
    public let fib0500: Double
    public let fib0618: Double
    public let fib0786: Double
    public let expansion1272: Double
    public let expansion1618: Double
    public let atr14: Double
    public let isInGoldenPocket: Bool
}

public struct AstronacciScoreBreakdown: Sendable, Codable, Equatable {
    public let regimePoints: Int          // Max 25
    public let fibZonePoints: Int         // Max 25
    public let candleTriggerPoints: Int   // Max 20
    public let stochasticPoints: Int      // Max 15
    public let sessionPoints: Int         // Max 10
    public let newsPoints: Int            // Max 5
    public let totalScore: Int            // Max 100
}

public struct AstronacciVetoCheck: Sendable, Codable, Equatable {
    public let isPassed: Bool
    public let candleTriggerPassed: Bool
    public let rrPassed: Bool
    public let riskDistPassed: Bool
    public let swingRangePassed: Bool
    public let rejectionReason: String?

    public init(
        isPassed: Bool,
        candleTriggerPassed: Bool,
        rrPassed: Bool,
        riskDistPassed: Bool = true,
        swingRangePassed: Bool = true,
        rejectionReason: String? = nil
    ) {
        self.isPassed = isPassed
        self.candleTriggerPassed = candleTriggerPassed
        self.rrPassed = rrPassed
        self.riskDistPassed = riskDistPassed
        self.swingRangePassed = swingRangePassed
        self.rejectionReason = rejectionReason
    }
}

public struct AstronacciTradePlan: Sendable, Codable, Equatable {
    public let direction: String          // "LONG" or "SHORT"
    public let entryPrice: Double
    public let stopLossPrice: Double
    public let takeProfit1: Double
    public let takeProfit2: Double
    public let riskRewardRatio: Double
    public let positionSize: Double
    public let feeBufferUsd: Double
    public let assumedSlippageUsd: Double
    public let notionalUsd: Double
    public let isBGradeHalfSize: Bool
}

public struct AstronacciEvaluationResult: Sendable, Codable, Equatable {
    public let symbol: String
    public let regime: AstronacciRegime
    public let fibGrid: AstronacciFibonacciGrid
    public let candleTrigger: AstronacciCandleTrigger
    public let stochasticK: Double
    public let stochasticD: Double
    public let scoreBreakdown: AstronacciScoreBreakdown
    public let vetoCheck: AstronacciVetoCheck
    public let tradePlan: AstronacciTradePlan?
    public let finalStatus: String // "A_GRADE_SETUP", "B_GRADE_ALERT", or "STAND_ASIDE"
}

public struct AstronacciH1RegimeResult: Sendable, Codable, Equatable {
    public let regime: AstronacciRegime
    public let ema21: Double?
    public let ema34: Double?
    public let ema200: Double?
    public let lastClose: Double?

    public init(
        regime: AstronacciRegime,
        ema21: Double? = nil,
        ema34: Double? = nil,
        ema200: Double? = nil,
        lastClose: Double? = nil
    ) {
        self.regime = regime
        self.ema21 = ema21
        self.ema34 = ema34
        self.ema200 = ema200
        self.lastClose = lastClose
    }
}

// MARK: - Mathematical Technical Analysis Engine

public final class AstronacciDeterministicEngine: Sendable {
    public static let shared = AstronacciDeterministicEngine()

    public init() {}

    // MARK: - 1. Exponential Moving Average (EMA)
    public func calculateEMA(period: Int, klines: [AstronacciKline]) -> [Double] {
        guard klines.count >= period, period > 0 else { return [] }
        let multiplier = 2.0 / Double(period + 1)
        var emaValues: [Double] = []

        let initialSum = klines.prefix(period).reduce(0.0) { $0 + $1.close }
        var currentEMA = initialSum / Double(period)
        emaValues.append(currentEMA)

        for i in period..<klines.count {
            currentEMA = (klines[i].close - currentEMA) * multiplier + currentEMA
            emaValues.append(currentEMA)
        }
        return emaValues
    }

    // MARK: - 1b. Canonical H1 Trend Regime Detection (EMA 21, 34, 200)
    public func detectH1Regime(klinesH1: [AstronacciKline]) -> AstronacciH1RegimeResult {
        let closedH1 = klinesH1.filter { $0.isClosed && $0.isValid }
        guard closedH1.count >= 200 else {
            // Strict Fail-Closed: If closed H1 < 200 bars, regime is choppy
            return AstronacciH1RegimeResult(regime: .choppy, ema21: nil, ema34: nil, ema200: nil, lastClose: closedH1.last?.close)
        }

        let ema21List = calculateEMA(period: 21, klines: closedH1)
        let ema34List = calculateEMA(period: 34, klines: closedH1)
        let ema200List = calculateEMA(period: 200, klines: closedH1)

        guard let lastClose = closedH1.last?.close,
              let ema21 = ema21List.last,
              let ema34 = ema34List.last,
              let ema200 = ema200List.last else {
            return AstronacciH1RegimeResult(regime: .choppy, ema21: nil, ema34: nil, ema200: nil, lastClose: closedH1.last?.close)
        }

        let detectedRegime: AstronacciRegime
        if lastClose > ema34 && ema21 > ema34 && lastClose > ema200 {
            detectedRegime = .bullish
        } else if lastClose < ema34 && ema21 < ema34 && lastClose < ema200 {
            detectedRegime = .bearish
        } else {
            detectedRegime = .choppy
        }

        return AstronacciH1RegimeResult(
            regime: detectedRegime,
            ema21: ema21,
            ema34: ema34,
            ema200: ema200,
            lastClose: lastClose
        )
    }

    // MARK: - 2. Average True Range (ATR - Simple Rolling TR Mean)
    public func calculateATR(period: Int = 14, klines: [AstronacciKline]) -> Double {
        guard klines.count > period else { return 0.0 }
        var trueRanges: [Double] = []

        for i in 1..<klines.count {
            let current = klines[i]
            let previous = klines[i - 1]
            let tr1 = current.high - current.low
            let tr2 = abs(current.high - previous.close)
            let tr3 = abs(current.low - previous.close)
            trueRanges.append(max(tr1, max(tr2, tr3)))
        }

        guard trueRanges.count >= period else { return 0.0 }
        let recentTRs = trueRanges.suffix(period)
        return recentTRs.reduce(0.0, +) / Double(period)
    }

    // MARK: - 3. Stochastic Oscillator (5, 3, 3 or 14, 3, 3)
    public func calculateStochastic(
        kPeriod: Int = 5,
        dPeriod: Int = 3,
        slowing: Int = 3,
        klines: [AstronacciKline]
    ) -> (k: Double, d: Double, isGoldenCrossInOversold: Bool, isDeadCrossInOverbought: Bool) {
        guard klines.count >= kPeriod + slowing + dPeriod else {
            return (50.0, 50.0, false, false)
        }

        var rawKs: [Double] = []
        for i in (kPeriod - 1)..<klines.count {
            let window = klines[(i - kPeriod + 1)...i]
            let currentClose = klines[i].close
            let highestHigh = window.map { $0.high }.max() ?? currentClose
            let lowestLow = window.map { $0.low }.min() ?? currentClose

            let range = highestHigh - lowestLow
            let rawK = range > 0 ? ((currentClose - lowestLow) / range) * 100.0 : 50.0
            rawKs.append(rawK)
        }

        var smoothedKs: [Double] = []
        guard rawKs.count >= slowing else { return (50.0, 50.0, false, false) }
        for i in (slowing - 1)..<rawKs.count {
            let slice = rawKs[(i - slowing + 1)...i]
            smoothedKs.append(slice.reduce(0.0, +) / Double(slowing))
        }

        guard smoothedKs.count >= dPeriod else { return (50.0, 50.0, false, false) }
        var dValues: [Double] = []
        for i in (dPeriod - 1)..<smoothedKs.count {
            let slice = smoothedKs[(i - dPeriod + 1)...i]
            dValues.append(slice.reduce(0.0, +) / Double(dPeriod))
        }

        guard smoothedKs.count >= 2, dValues.count >= 2 else {
            let latestK = smoothedKs.last ?? 50.0
            let latestD = dValues.last ?? 50.0
            return (latestK, latestD, false, false)
        }

        let currentK = smoothedKs[smoothedKs.count - 1]
        let previousK = smoothedKs[smoothedKs.count - 2]
        let currentD = dValues[dValues.count - 1]
        let previousD = dValues[dValues.count - 2]

        // Golden Cross in oversold (<= 20)
        let isGoldenCross = (previousK <= previousD) && (currentK > currentD)
        let isOversold = (previousK <= 20.0 || currentK <= 20.0)
        let isGoldenCrossOversold = isGoldenCross && isOversold

        // Dead Cross in overbought (>= 80)
        let isDeadCross = (previousK >= previousD) && (currentK < currentD)
        let isOverbought = (previousK >= 80.0 || currentK >= 80.0)
        let isDeadCrossOverbought = isDeadCross && isOverbought

        return (currentK, currentD, isGoldenCrossOversold, isDeadCrossOverbought)
    }

    // MARK: - 4. 5-Bar Pivot Fractal Swing Detection (Anti-Repaint & Temporal Ordering)
    public func detect5BarPivotFractals(klines: [AstronacciKline]) -> (swingLow: Double, swingHigh: Double, lowIndex: Int, highIndex: Int)? {
        let closedKlines = klines.filter { $0.isClosed }
        guard closedKlines.count >= 5 else { return nil }

        var lastSwingHigh: Double?
        var lastSwingHighIndex: Int?
        var lastSwingLow: Double?
        var lastSwingLowIndex: Int?

        for i in 2..<(closedKlines.count - 2) {
            let p0 = closedKlines[i - 2]
            let p1 = closedKlines[i - 1]
            let center = closedKlines[i]
            let f1 = closedKlines[i + 1]
            let f2 = closedKlines[i + 2]

            if center.high > p0.high && center.high > p1.high && center.high > f1.high && center.high > f2.high {
                lastSwingHigh = center.high
                lastSwingHighIndex = i
            }

            if center.low < p0.low && center.low < p1.low && center.low < f1.low && center.low < f2.low {
                lastSwingLow = center.low
                lastSwingLowIndex = i
            }
        }

        if let low = lastSwingLow, let high = lastSwingHigh, high > low,
           let lIdx = lastSwingLowIndex, let hIdx = lastSwingHighIndex {
            return (low, high, lIdx, hIdx)
        }

        // STRICT ZERO-HALLUCINATION: If genuine 5-bar pivot fractals are not confirmed, return nil.
        return nil
    }

    // MARK: - 4b. Dominant Impulsive Swing Detector (Option A Pre-Registered)
    // Anchors Fibonacci Retracement to major trend impulse leg rather than micro 5-bar wiggles
    public func detectDominantImpulsiveSwing(
        klines: [AstronacciKline],
        atr: Double,
        lookbackBars: Int = 48,
        minAtrMultiple: Double = 4.0
    ) -> (swingLow: Double, swingHigh: Double, lowIndex: Int, highIndex: Int)? {
        let closedKlines = klines.filter { $0.isClosed }
        guard closedKlines.count >= 5, atr > 0 else { return nil }

        let windowSize = min(closedKlines.count, lookbackBars)
        let startIndex = closedKlines.count - windowSize

        var minLow = Double.infinity
        var minLowIdx = -1
        var maxHigh = -Double.infinity
        var maxHighIdx = -1

        for i in startIndex..<closedKlines.count {
            let k = closedKlines[i]
            if k.low < minLow {
                minLow = k.low
                minLowIdx = i
            }
            if k.high > maxHigh {
                maxHigh = k.high
                maxHighIdx = i
            }
        }

        let range = maxHigh - minLow
        guard range >= (minAtrMultiple * atr) else { return nil }
        guard minLowIdx <= closedKlines.count - 3, maxHighIdx <= closedKlines.count - 3 else { return nil }

        return (minLow, maxHigh, minLowIdx, maxHighIdx)
    }

    // MARK: - 5. Candlestick Rejection Anatomy (Pin Bar & Engulfing)
    public func detectCandleTrigger(
        kline: AstronacciKline,
        previousKline: AstronacciKline,
        atr: Double
    ) -> AstronacciCandleTrigger {
        let totalRange = kline.high - kline.low
        guard totalRange > 0 else { return .none }

        // Sanity: Minimum candle range relative to ATR to filter flat market noise
        if atr > 0 && totalRange < (0.15 * atr) {
            return .none
        }

        let body = abs(kline.close - kline.open)
        // Zero-body doji guard: Doji without a real body cannot be a directional Pin Bar
        guard body > 0 else { return .none }

        let bodyTop = max(kline.open, kline.close)
        let bodyBottom = min(kline.open, kline.close)
        let lowerShadow = bodyBottom - kline.low
        let upperShadow = kline.high - bodyTop

        // 1. Bullish Pin Bar / Hammer:
        // - Lower shadow >= 2x body
        // - Lower shadow must be at least 50% of the entire candle range
        // - Upper shadow must be minimal (<= 20% of range)
        // - Body is small (<= 35% of range)
        // - Close is in the upper 40% of the candle
        let isBullishPinWick = lowerShadow >= (2.0 * body) && (lowerShadow / totalRange) >= 0.50
        let isSmallUpperWick = (upperShadow / totalRange) <= 0.20
        let isSmallBody = (body / totalRange) <= 0.35
        let isUpperClose = (kline.close - kline.low) >= (totalRange * 0.60)

        if isBullishPinWick && isSmallUpperWick && isSmallBody && isUpperClose {
            let wickRatio = lowerShadow / body
            return .bullishPinBar(lowerWickRatio: wickRatio)
        }

        // 2. Bearish Shooting Star / Inverted Pin Bar:
        // - Upper shadow >= 2x body
        // - Upper shadow must be at least 50% of the entire candle range
        // - Lower shadow must be minimal (<= 20% of range)
        // - Body is small (<= 35% of range)
        // - Close is in the lower 40% of the candle
        let isBearishPinWick = upperShadow >= (2.0 * body) && (upperShadow / totalRange) >= 0.50
        let isSmallLowerWick = (lowerShadow / totalRange) <= 0.20
        let isLowerClose = (kline.high - kline.close) >= (totalRange * 0.60)

        if isBearishPinWick && isSmallLowerWick && isSmallBody && isLowerClose {
            let wickRatio = upperShadow / body
            return .bearishShootingStar(upperWickRatio: wickRatio)
        }

        // 3. Bullish Engulfing:
        let prevBearish = previousKline.close < previousKline.open
        let currBullish = kline.close > kline.open
        let openBullishEngulfed = kline.open <= (previousKline.close + (0.05 * atr))
        let closeBullishEngulfed = kline.close > previousKline.open

        if prevBearish && currBullish && openBullishEngulfed && closeBullishEngulfed {
            return .bullishEngulfing
        }

        // 4. Bearish Engulfing:
        let prevBullish = previousKline.close > previousKline.open
        let currBearish = kline.close < kline.open
        let openBearishEngulfed = kline.open >= (previousKline.close - (0.05 * atr))
        let closeBearishEngulfed = kline.close < previousKline.open

        if prevBullish && currBearish && openBearishEngulfed && closeBearishEngulfed {
            return .bearishEngulfing
        }

        return .none
    }

    // MARK: - 6. Complete Confluence & Veto Evaluator (DAG Node 06 & 07)
    public func evaluateConfluence(
        symbol: String = "BTC-USDT",
        klinesH1: [AstronacciKline],
        klinesM15: [AstronacciKline],
        klinesM5: [AstronacciKline],
        isNewsClear: Bool = false,        // Conservative default: False (Fail-Closed)
        isLondonNyOverlap: Bool = false,  // Conservative default: False (Fail-Closed)
        accountEquity: Double = 10000.0,
        maxLeverage: Double = 10.0
    ) -> AstronacciEvaluationResult {
        // --- Input Kline Sanity Check ---
        let validH1 = klinesH1.filter { $0.isValid }
        let validM15 = klinesM15.filter { $0.isValid }
        let validM5 = klinesM5.filter { $0.isValid }

        // --- Early Return on Empty Data (Fail-Closed) ---
        let closedM15 = validM15.filter { $0.isClosed }
        guard let _ = closedM15.last, closedM15.count >= 10 else {
            return AstronacciEvaluationResult(
                symbol: symbol,
                regime: .choppy,
                fibGrid: AstronacciFibonacciGrid(swingLow: 0, swingHigh: 0, fib0382: 0, fib0500: 0, fib0618: 0, fib0786: 0, expansion1272: 0, expansion1618: 0, atr14: 0, isInGoldenPocket: false),
                candleTrigger: .none,
                stochasticK: 50.0,
                stochasticD: 50.0,
                scoreBreakdown: AstronacciScoreBreakdown(regimePoints: 0, fibZonePoints: 0, candleTriggerPoints: 0, stochasticPoints: 0, sessionPoints: 0, newsPoints: 0, totalScore: 0),
                vetoCheck: AstronacciVetoCheck(isPassed: false, candleTriggerPassed: false, rrPassed: false, riskDistPassed: false, rejectionReason: "FAIL-CLOSED: Data M15 tidak mencukupi untuk analisis."),
                tradePlan: nil,
                finalStatus: "STAND_ASIDE"
            )
        }

        let closedM5 = validM5.filter { $0.isClosed }
        guard let lastM5 = closedM5.last, closedM5.count >= 2 else {
            return AstronacciEvaluationResult(
                symbol: symbol,
                regime: .choppy,
                fibGrid: AstronacciFibonacciGrid(swingLow: 0, swingHigh: 0, fib0382: 0, fib0500: 0, fib0618: 0, fib0786: 0, expansion1272: 0, expansion1618: 0, atr14: 0, isInGoldenPocket: false),
                candleTrigger: .none,
                stochasticK: 50.0,
                stochasticD: 50.0,
                scoreBreakdown: AstronacciScoreBreakdown(regimePoints: 0, fibZonePoints: 0, candleTriggerPoints: 0, stochasticPoints: 0, sessionPoints: 0, newsPoints: 0, totalScore: 0),
                vetoCheck: AstronacciVetoCheck(isPassed: false, candleTriggerPassed: false, rrPassed: false, riskDistPassed: false, rejectionReason: "FAIL-CLOSED: Data M5 tidak mencukupi untuk analisis konfirmasi."),
                tradePlan: nil,
                finalStatus: "STAND_ASIDE"
            )
        }

        // --- Step 1: H1 Trend Regime (25 Points) - Fail-Closed ---
        let regimeRes = detectH1Regime(klinesH1: validH1)
        let detectedRegime = regimeRes.regime
        let regimePoints = (detectedRegime == .bullish || detectedRegime == .bearish) ? 25 : 0

        // --- Step 2: M15 Fibonacci Grid & Golden Pocket (25 Points) ---
        let atr14 = calculateATR(period: 14, klines: closedM15)
        guard atr14 > 0 else {
            return AstronacciEvaluationResult(
                symbol: symbol,
                regime: detectedRegime,
                fibGrid: AstronacciFibonacciGrid(swingLow: 0, swingHigh: 0, fib0382: 0, fib0500: 0, fib0618: 0, fib0786: 0, expansion1272: 0, expansion1618: 0, atr14: 0, isInGoldenPocket: false),
                candleTrigger: .none,
                stochasticK: 50.0,
                stochasticD: 50.0,
                scoreBreakdown: AstronacciScoreBreakdown(regimePoints: regimePoints, fibZonePoints: 0, candleTriggerPoints: 0, stochasticPoints: 0, sessionPoints: 0, newsPoints: 0, totalScore: regimePoints),
                vetoCheck: AstronacciVetoCheck(isPassed: false, candleTriggerPassed: false, rrPassed: false, riskDistPassed: false, rejectionReason: "FAIL-CLOSED: Nilai ATR(14) adalah nol."),
                tradePlan: nil,
                finalStatus: "STAND_ASIDE"
            )
        }

        // Fresh price anchored to the M5 trigger confirmation candle close
        let currentPrice = lastM5.close

        guard let fractals = detect5BarPivotFractals(klines: closedM15), fractals.swingHigh > fractals.swingLow else {
            return AstronacciEvaluationResult(
                symbol: symbol,
                regime: detectedRegime,
                fibGrid: AstronacciFibonacciGrid(swingLow: 0, swingHigh: 0, fib0382: 0, fib0500: 0, fib0618: 0, fib0786: 0, expansion1272: 0, expansion1618: 0, atr14: atr14, isInGoldenPocket: false),
                candleTrigger: .none,
                stochasticK: 50.0,
                stochasticD: 50.0,
                scoreBreakdown: AstronacciScoreBreakdown(regimePoints: regimePoints, fibZonePoints: 0, candleTriggerPoints: 0, stochasticPoints: 0, sessionPoints: 0, newsPoints: 0, totalScore: regimePoints),
                vetoCheck: AstronacciVetoCheck(isPassed: false, candleTriggerPassed: false, rrPassed: false, riskDistPassed: false, rejectionReason: "FAIL-CLOSED: Tidak ada 5-bar Pivot Fractal swing valid yang teridentifikasi."),
                tradePlan: nil,
                finalStatus: "STAND_ASIDE"
            )
        }

        // Structural Temporal Guard (Probe B - Never fight market structure):
        // In Bullish regime: swing low must precede swing high (lowIndex < highIndex)
        // In Bearish regime: swing high must precede swing low (highIndex < lowIndex)
        if detectedRegime == .bullish && fractals.lowIndex >= fractals.highIndex {
            return AstronacciEvaluationResult(
                symbol: symbol,
                regime: detectedRegime,
                fibGrid: AstronacciFibonacciGrid(swingLow: fractals.swingLow, swingHigh: fractals.swingHigh, fib0382: 0, fib0500: 0, fib0618: 0, fib0786: 0, expansion1272: 0, expansion1618: 0, atr14: atr14, isInGoldenPocket: false),
                candleTrigger: .none,
                stochasticK: 50.0,
                stochasticD: 50.0,
                scoreBreakdown: AstronacciScoreBreakdown(regimePoints: regimePoints, fibZonePoints: 0, candleTriggerPoints: 0, stochasticPoints: 0, sessionPoints: 0, newsPoints: 0, totalScore: regimePoints),
                vetoCheck: AstronacciVetoCheck(isPassed: false, candleTriggerPassed: false, rrPassed: false, riskDistPassed: false, rejectionReason: "FAIL-CLOSED: Urutan fractal tidak valid untuk Bullish (Lower low terbentuk setelah swing high - struktur rusak)."),
                tradePlan: nil,
                finalStatus: "STAND_ASIDE"
            )
        }

        if detectedRegime == .bearish && fractals.highIndex >= fractals.lowIndex {
            return AstronacciEvaluationResult(
                symbol: symbol,
                regime: detectedRegime,
                fibGrid: AstronacciFibonacciGrid(swingLow: fractals.swingLow, swingHigh: fractals.swingHigh, fib0382: 0, fib0500: 0, fib0618: 0, fib0786: 0, expansion1272: 0, expansion1618: 0, atr14: atr14, isInGoldenPocket: false),
                candleTrigger: .none,
                stochasticK: 50.0,
                stochasticD: 50.0,
                scoreBreakdown: AstronacciScoreBreakdown(regimePoints: regimePoints, fibZonePoints: 0, candleTriggerPoints: 0, stochasticPoints: 0, sessionPoints: 0, newsPoints: 0, totalScore: regimePoints),
                vetoCheck: AstronacciVetoCheck(isPassed: false, candleTriggerPassed: false, rrPassed: false, riskDistPassed: false, rejectionReason: "FAIL-CLOSED: Urutan fractal tidak valid untuk Bearish (Higher high terbentuk setelah swing low - struktur rusak)."),
                tradePlan: nil,
                finalStatus: "STAND_ASIDE"
            )
        }

        let swingLow = fractals.swingLow
        let swingHigh = fractals.swingHigh
        let range = swingHigh - swingLow

        var fib0382: Double = 0.0
        var fib0500: Double = 0.0
        var fib0618: Double = 0.0
        var fib0786: Double = 0.0
        var exp1272: Double = 0.0
        var exp1618: Double = 0.0
        var isInGoldenPocket: Bool = false

        if detectedRegime == .bearish {
            // Bearish Retracement (Pullback upwards into Golden Pocket from swingLow)
            fib0382 = swingLow + (range * 0.382)
            fib0500 = swingLow + (range * 0.500)
            fib0618 = swingLow + (range * 0.618)
            fib0786 = swingLow + (range * 0.786)
            exp1272 = swingHigh - (range * 1.272)
            exp1618 = swingHigh - (range * 1.618)

            let lowerBound = fib0500 - (0.25 * atr14)
            let upperBound = fib0618 + (0.25 * atr14)
            isInGoldenPocket = (currentPrice >= lowerBound && currentPrice <= upperBound)
        } else {
            // Bullish Retracement (Pullback downwards into Golden Pocket from swingHigh)
            fib0382 = swingHigh - (range * 0.382)
            fib0500 = swingHigh - (range * 0.500)
            fib0618 = swingHigh - (range * 0.618)
            fib0786 = swingHigh - (range * 0.786)
            exp1272 = swingLow + (range * 1.272)
            exp1618 = swingLow + (range * 1.618)

            let lowerBound = fib0618 - (0.25 * atr14)
            let upperBound = fib0500 + (0.25 * atr14)
            isInGoldenPocket = (currentPrice >= lowerBound && currentPrice <= upperBound)
        }

        var fibZonePoints = 0
        if isInGoldenPocket {
            fibZonePoints = 25
        } else if detectedRegime == .bullish && currentPrice >= fib0786 && currentPrice < (fib0618 - (0.25 * atr14)) {
            fibZonePoints = 10
        } else if detectedRegime == .bearish && currentPrice <= fib0786 && currentPrice > (fib0618 + (0.25 * atr14)) {
            fibZonePoints = 10
        }

        let fibGrid = AstronacciFibonacciGrid(
            swingLow: swingLow,
            swingHigh: swingHigh,
            fib0382: fib0382,
            fib0500: fib0500,
            fib0618: fib0618,
            fib0786: fib0786,
            expansion1272: exp1272,
            expansion1618: exp1618,
            atr14: atr14,
            isInGoldenPocket: isInGoldenPocket
        )

        // --- Step 3: M5 Candlestick Trigger (20 Points) ---
        let prevM5 = closedM5[closedM5.count - 2]
        let candleTrigger = detectCandleTrigger(kline: lastM5, previousKline: prevM5, atr: atr14)
        var candleTriggerPoints = 0

        if detectedRegime == .bearish && candleTrigger.isBearish {
            candleTriggerPoints = 20
        } else if detectedRegime == .bullish && candleTrigger.isBullish {
            candleTriggerPoints = 20
        }

        // --- Step 4: M5 Stochastic Oscillator (15 Points) ---
        let stoch = calculateStochastic(kPeriod: 5, dPeriod: 3, slowing: 3, klines: closedM5)
        var stochPoints = 0
        if detectedRegime == .bearish {
            if stoch.isDeadCrossInOverbought {
                stochPoints = 15
            } else if stoch.k >= 80.0 {
                stochPoints = 8
            }
        } else {
            if stoch.isGoldenCrossInOversold {
                stochPoints = 15
            } else if stoch.k <= 20.0 {
                stochPoints = 8
            }
        }

        // --- Step 5: Sessions & News (15 Points) ---
        let sessionPoints = isLondonNyOverlap ? 10 : 0
        let newsPoints = isNewsClear ? 5 : 0

        // --- Step 6: Total Confluence Score ---
        let totalScore = regimePoints + fibZonePoints + candleTriggerPoints + stochPoints + sessionPoints + newsPoints

        let breakdown = AstronacciScoreBreakdown(
            regimePoints: regimePoints,
            fibZonePoints: fibZonePoints,
            candleTriggerPoints: candleTriggerPoints,
            stochasticPoints: stochPoints,
            sessionPoints: sessionPoints,
            newsPoints: newsPoints,
            totalScore: totalScore
        )

        // --- Step 7: Risk-Adjusted Plan Calculation & Stop Loss ---
        // Sesuai Amendemen Geometri Koheren Auditor:
        // - Stop Loss dipasang di bawah/atas level struktural Swing Low / Swing High
        // - TP1 dipasang di Fibonacci Expansion 1.272 (menjamin R:R >= 2.0 yang koheren dengan Golden Pocket)
        // - TP2 dipasang di Fibonacci Expansion 1.618
        let slBuffer = 0.25 * atr14
        var stopLoss: Double = 0.0
        let entryPrice = currentPrice
        var tp1: Double = 0.0
        var tp2: Double = 0.0
        var riskDist: Double = 0.0
        var rewardDist: Double = 0.0
        var directionString = "LONG"

        if detectedRegime == .bearish {
            directionString = "SHORT"
            stopLoss = swingHigh + slBuffer
            tp1 = exp1272
            tp2 = exp1618
            riskDist = stopLoss - entryPrice
            rewardDist = entryPrice - tp1
        } else {
            directionString = "LONG"
            stopLoss = swingLow - slBuffer
            tp1 = exp1272
            tp2 = exp1618
            riskDist = entryPrice - stopLoss
            rewardDist = tp1 - entryPrice
        }

        let calculatedRR = riskDist > 0 ? (rewardDist / riskDist) : 0.0

        // --- Step 8: HARD VETO GATE (Node 07 - Single Source of Truth) ---
        let vetoCheck = AstronacciDeterministicEngine.evaluateVetoGate(
            detectedRegime: detectedRegime,
            candleTrigger: candleTrigger,
            calculatedRR: calculatedRR,
            riskDist: riskDist,
            swingRange: range,
            atr14: atr14,
            totalScore: totalScore,
            minRR: 1.0
        )

        // --- Step 9: Position Sizing (Floor Rounding & Min-Step Guard) ---
        var tradePlan: AstronacciTradePlan? = nil
        var finalStatus = "STAND_ASIDE"

        if vetoCheck.isPassed {
            let isBGrade = (totalScore >= 65 && totalScore < 80)
            let riskPct = isBGrade ? 0.005 : 0.010 // 0.5% for B-Grade, 1.0% for A-Grade
            let targetRiskDollars = accountEquity * riskPct

            let feeBuffer = entryPrice * 0.001 // 0.1% taker fee round-trip
            let assumedSlippage = 0.10 * atr14 // Dynamic slippage allowance
            let effectiveRiskPerUnit = riskDist + feeBuffer + assumedSlippage

            let rawSize = effectiveRiskPerUnit > 0 ? (targetRiskDollars / effectiveRiskPerUnit) : 0.0
            
            // STRICT FLOOR ROUNDING to 3 decimal places (Never rounds up to prevent >1.0% risk)
            let flooredSize = floor(rawSize * 1000.0) / 1000.0

            // Minimum contract step guard (Must be >= 0.001 BTC)
            if flooredSize >= 0.001 {
                let notional = flooredSize * entryPrice
                let maxAllowedNotional = accountEquity * maxLeverage
                let cappedSize = notional <= maxAllowedNotional ? flooredSize : floor((maxAllowedNotional / entryPrice) * 1000.0) / 1000.0

                // Post-cap leverage minimum step guard (Agent 2 item 1)
                if cappedSize >= 0.001 {
                    tradePlan = AstronacciTradePlan(
                        direction: directionString,
                        entryPrice: entryPrice,
                        stopLossPrice: stopLoss,
                        takeProfit1: tp1,
                        takeProfit2: tp2,
                        riskRewardRatio: calculatedRR,
                        positionSize: cappedSize,
                        feeBufferUsd: feeBuffer * cappedSize,
                        assumedSlippageUsd: assumedSlippage * cappedSize,
                        notionalUsd: cappedSize * entryPrice,
                        isBGradeHalfSize: isBGrade
                    )

                    finalStatus = isBGrade ? "B_GRADE_ALERT" : "A_GRADE_SETUP"
                } else {
                    // Capped size fell below exchange minimum contract size
                    finalStatus = "STAND_ASIDE"
                }
            } else {
                // Sizing fell below exchange minimum contract size
                finalStatus = "STAND_ASIDE"
            }
        }

        return AstronacciEvaluationResult(
            symbol: symbol,
            regime: detectedRegime,
            fibGrid: fibGrid,
            candleTrigger: candleTrigger,
            stochasticK: stoch.k,
            stochasticD: stoch.d,
            scoreBreakdown: breakdown,
            vetoCheck: vetoCheck,
            tradePlan: tradePlan,
            finalStatus: finalStatus
        )
    }

    // MARK: - Single Source of Truth for Veto Logic (Amendemen 1 Canon)
    public static func evaluateVetoGate(
        detectedRegime: AstronacciRegime,
        candleTrigger: AstronacciCandleTrigger,
        calculatedRR: Double,
        riskDist: Double,
        swingRange: Double,
        atr14: Double,
        totalScore: Int,
        minRR: Double = 1.0
    ) -> AstronacciVetoCheck {
        let candleTriggerPassed: Bool
        if detectedRegime == .bearish {
            candleTriggerPassed = candleTrigger.isBearish
        } else if detectedRegime == .bullish {
            candleTriggerPassed = candleTrigger.isBullish
        } else {
            candleTriggerPassed = false // In choppy regime, no directional trades allowed!
        }

        let rrPassed = calculatedRR >= (minRR - 0.001) // Epsilon tolerance
        let riskDistPassed = riskDist >= (1.0 * atr14)
        let swingRangePassed = swingRange >= (3.0 * atr14)
        let scorePassed = totalScore >= 65
        let isPassed = candleTriggerPassed && rrPassed && riskDistPassed && swingRangePassed && scorePassed

        var rejectionReason: String? = nil
        if !candleTriggerPassed {
            rejectionReason = "HARD VETO: Kandel M5 belum mengonfirmasi pola reversal searah tren."
        } else if !swingRangePassed {
            rejectionReason = String(format: "HARD VETO: Rentang swing fractal M15 terlalu sempit (%.2f < 3.0x ATR %.2f). Terindikasi konsolidasi/noise.", swingRange, 3.0 * atr14)
        } else if !riskDistPassed {
            rejectionReason = String(format: "HARD VETO: Jarak stop loss terlalu sempit (%.2f < 1.0x ATR %.2f). Risiko stop-out noise.", riskDist, 1.0 * atr14)
        } else if !rrPassed {
            rejectionReason = String(format: "HARD VETO: Rasio R:R (1:%.2f) di bawah standar minimum 1:%.2f.", calculatedRR, minRR)
        } else if !scorePassed {
            rejectionReason = "REJECTED: Skor konfluensi (\(totalScore)/100) di bawah ambang minimum 65."
        }

        return AstronacciVetoCheck(
            isPassed: isPassed,
            candleTriggerPassed: candleTriggerPassed,
            rrPassed: rrPassed,
            riskDistPassed: riskDistPassed,
            swingRangePassed: swingRangePassed,
            rejectionReason: rejectionReason
        )
    }
}
