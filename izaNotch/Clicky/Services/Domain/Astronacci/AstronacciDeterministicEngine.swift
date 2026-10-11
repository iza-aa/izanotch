//
//  AstronacciDeterministicEngine.swift
//  izaNotch (Izanotchy Futures Scout)
//
//  Mathematical & Deterministic Technical Analysis Engine
//  Implements the canonical Astronacci Scalping Specification:
//  - Multi-Timeframe Regime (EMA 21, EMA 34, EMA 200 on H1, Fail-Closed on < 200 bars)
//  - Dual-Direction Support: Bullish Long AND Bearish Short Setups
//  - 5-Bar Pivot Fractal Swing Detection on Closed M15 Candles (Anti-Repaint)
//  - Impulsive Swing Detection with Dynamic ATR Multiplier
//  - Stochastic Oscillator (5, 3, 3) Golden Cross in Oversold (<= 20)
//  - Candlestick Rejection Anatomy (Pin Bar & Engulfing)
//

import Foundation

public struct AstronacciKline: Sendable, Codable, Equatable {
    public let open: Double
    public let high: Double
    public let low: Double
    public let close: Double
    public let volume: Double
    public let timestamp: Int64
    public let isClosed: Bool

    public var isValid: Bool {
        return open > 0 && high > 0 && low > 0 && close > 0 && high >= low
    }

    public init(
        open: Double,
        high: Double,
        low: Double,
        close: Double,
        volume: Double = 0.0,
        timestamp: Int64 = 0,
        isClosed: Bool = true
    ) {
        self.open = open
        self.high = high
        self.low = low
        self.close = close
        self.volume = volume
        self.timestamp = timestamp
        self.isClosed = isClosed
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

}

public struct AstronacciH1RegimeResult: Sendable, Codable, Equatable {
    public let regime: AstronacciRegime

    public init(regime: AstronacciRegime) {
        self.regime = regime
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
            return AstronacciH1RegimeResult(regime: .choppy)
        }

        let ema21List = calculateEMA(period: 21, klines: closedH1)
        let ema34List = calculateEMA(period: 34, klines: closedH1)
        let ema200List = calculateEMA(period: 200, klines: closedH1)

        guard let lastClose = closedH1.last?.close,
              let ema21 = ema21List.last,
              let ema34 = ema34List.last,
              let ema200 = ema200List.last else {
            return AstronacciH1RegimeResult(regime: .choppy)
        }

        let detectedRegime: AstronacciRegime
        if lastClose > ema34 && ema21 > ema34 && lastClose > ema200 {
            detectedRegime = .bullish
        } else if lastClose < ema34 && ema21 < ema34 && lastClose < ema200 {
            detectedRegime = .bearish
        } else {
            detectedRegime = .choppy
        }

        return AstronacciH1RegimeResult(regime: detectedRegime)
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

        let isGoldenCross = (previousK <= previousD) && (currentK > currentD)
        let isOversold = (previousK <= 20.0 || currentK <= 20.0)
        let isGoldenCrossOversold = isGoldenCross && isOversold

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

        return nil
    }

    // MARK: - 4b. Dominant Impulsive Swing Detector
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

        if atr > 0 && totalRange < (0.15 * atr) {
            return .none
        }

        let body = abs(kline.close - kline.open)
        guard body > 0 else { return .none }

        let bodyTop = max(kline.open, kline.close)
        let bodyBottom = min(kline.open, kline.close)
        let lowerShadow = bodyBottom - kline.low
        let upperShadow = kline.high - bodyTop

        let isBullishPinWick = lowerShadow >= (2.0 * body) && (lowerShadow / totalRange) >= 0.50
        let isSmallUpperWick = (upperShadow / totalRange) <= 0.20
        let isSmallBody = (body / totalRange) <= 0.35
        let isUpperClose = (kline.close - kline.low) >= (totalRange * 0.60)

        if isBullishPinWick && isSmallUpperWick && isSmallBody && isUpperClose {
            let wickRatio = lowerShadow / body
            return .bullishPinBar(lowerWickRatio: wickRatio)
        }

        let isBearishPinWick = upperShadow >= (2.0 * body) && (upperShadow / totalRange) >= 0.50
        let isSmallLowerWick = (lowerShadow / totalRange) <= 0.20
        let isLowerClose = (kline.high - kline.close) >= (totalRange * 0.60)

        if isBearishPinWick && isSmallLowerWick && isSmallBody && isLowerClose {
            let wickRatio = upperShadow / body
            return .bearishShootingStar(upperWickRatio: wickRatio)
        }

        let prevBearish = previousKline.close < previousKline.open
        let currBullish = kline.close > kline.open
        let openBullishEngulfed = kline.open <= (previousKline.close + (0.05 * atr))
        let closeBullishEngulfed = kline.close > previousKline.open

        if prevBearish && currBullish && openBullishEngulfed && closeBullishEngulfed {
            return .bullishEngulfing
        }

        let prevBullish = previousKline.close > previousKline.open
        let currBearish = kline.close < kline.open
        let openBearishEngulfed = kline.open >= (previousKline.close - (0.05 * atr))
        let closeBearishEngulfed = kline.close < previousKline.open

        if prevBullish && currBearish && openBearishEngulfed && closeBearishEngulfed {
            return .bearishEngulfing
        }

        return .none
    }
}
