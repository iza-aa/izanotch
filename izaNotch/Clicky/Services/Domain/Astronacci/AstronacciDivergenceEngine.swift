//
//  AstronacciDivergenceEngine.swift
//  izaNotch
//
//  Created for Izanotchy - Advanced Astronacci Foundations (Pillar 10: Divergensi Struktural Matematis)
//  Detects Regular & Hidden Divergences between Price Swing Pivots and Stochastic Oscillator (14,3,3 / 5,3,3)
//  Strictly pure-mathematical, zero external dependencies, thread-safe & Sendable.
//

import Foundation

public enum DivergenceType: String, Equatable, Sendable, CaseIterable {
    case regularBullish = "Regular Bullish Divergence (Pembalikan Bullish)"
    case regularBearish = "Regular Bearish Divergence (Pembalikan Bearish)"
    case hiddenBullish = "Hidden Bullish Divergence (Kelanjutan Tren Naik)"
    case hiddenBearish = "Hidden Bearish Divergence (Kelanjutan Tren Turun)"
    case none = "Tidak Ada Divergensi"
}

struct DivergencePivot: Equatable, Sendable {
    let barIndex: Int
    let price: Double
    let oscValue: Double

    init(barIndex: Int, price: Double, oscValue: Double) {
        self.barIndex = barIndex
        self.price = price
        self.oscValue = oscValue
    }
}

public struct AstronacciDivergenceResult: Equatable, Sendable {
    public let type: DivergenceType
    public let isBullish: Bool
    public let description: String

    public init(
        type: DivergenceType,
        isBullish: Bool,
        description: String
    ) {
        self.type = type
        self.isBullish = isBullish
        self.description = description
    }

    public static let none = AstronacciDivergenceResult(
        type: .none,
        isBullish: false,
        description: "Tidak terdeteksi divergensi pada Stochastic M15."
    )
}

struct AstronacciDivergenceEngine: Sendable {
    init() {}

    /// Evaluates divergence between two low pivots (troughs)
    func evaluateLowPivotsDivergence(
        first: DivergencePivot,
        second: DivergencePivot,
        currentBarIndex: Int,
        maxAgeBars: Int = 8
    ) -> AstronacciDivergenceResult {
        let age = currentBarIndex - second.barIndex
        guard age >= 0, age <= maxAgeBars else {
            return .none
        }

        // Price Lower Low & Oscillator Higher Low -> Regular Bullish
        if second.price < first.price && second.oscValue > first.oscValue {
            return AstronacciDivergenceResult(
                type: .regularBullish,
                isBullish: true,
                description: "Regular Bullish Divergence (terkonfirmasi \(age) bar lalu): Harga membentuk Lower Low (\(String(format: "%.2f", first.price)) -> \(String(format: "%.2f", second.price))), namun Stochastic membentuk Higher Low (\(String(format: "%.1f", first.oscValue)) -> \(String(format: "%.1f", second.oscValue)))."
            )
        }

        // Price Higher Low & Oscillator Lower Low -> Hidden Bullish (Trend Continuation)
        if second.price > first.price && second.oscValue < first.oscValue {
            return AstronacciDivergenceResult(
                type: .hiddenBullish,
                isBullish: true,
                description: "Hidden Bullish Divergence (terkonfirmasi \(age) bar lalu): Harga membentuk Higher Low (\(String(format: "%.2f", first.price)) -> \(String(format: "%.2f", second.price))), namun Stochastic membentuk Lower Low (\(String(format: "%.1f", first.oscValue)) -> \(String(format: "%.1f", second.oscValue)))."
            )
        }

        return .none
    }

    /// Evaluates divergence between two high pivots (crests)
    func evaluateHighPivotsDivergence(
        first: DivergencePivot,
        second: DivergencePivot,
        currentBarIndex: Int,
        maxAgeBars: Int = 8
    ) -> AstronacciDivergenceResult {
        let age = currentBarIndex - second.barIndex
        guard age >= 0, age <= maxAgeBars else {
            return .none
        }

        if second.price > first.price && second.oscValue < first.oscValue {
            return AstronacciDivergenceResult(
                type: .regularBearish,
                isBullish: false,
                description: "Regular Bearish Divergence (terkonfirmasi \(age) bar lalu): Harga membentuk Higher High (\(String(format: "%.2f", first.price)) -> \(String(format: "%.2f", second.price))), namun Stochastic membentuk Lower High (\(String(format: "%.1f", first.oscValue)) -> \(String(format: "%.1f", second.oscValue)))."
            )
        }

        if second.price < first.price && second.oscValue > first.oscValue {
            return AstronacciDivergenceResult(
                type: .hiddenBearish,
                isBullish: false,
                description: "Hidden Bearish Divergence (terkonfirmasi \(age) bar lalu): Harga membentuk Lower High (\(String(format: "%.2f", first.price)) -> \(String(format: "%.2f", second.price))), namun Stochastic membentuk Higher High (\(String(format: "%.1f", first.oscValue)) -> \(String(format: "%.1f", second.oscValue)))."
            )
        }

        return .none
    }

    /// Calculates bar-aligned Stochastic %K series
    func calculateStochasticSeries(
        kPeriod: Int = 14,
        slowing: Int = 3,
        klines: [AstronacciKline]
    ) -> [Double] {
        guard klines.count >= kPeriod + slowing else {
            return Array(repeating: 50.0, count: klines.count)
        }

        // Step 1: Raw %K
        var rawK = Array(repeating: 50.0, count: klines.count)
        for i in (kPeriod - 1)..<klines.count {
            let window = klines[(i - kPeriod + 1)...i]
            let highestHigh = window.map { $0.high }.max() ?? klines[i].high
            let lowestLow = window.map { $0.low }.min() ?? klines[i].low
            let range = highestHigh - lowestLow
            rawK[i] = range > 0 ? ((klines[i].close - lowestLow) / range) * 100.0 : 50.0
        }

        // Step 2: Smoothed %K (SMA of rawK over `slowing` periods)
        var smoothedK = Array(repeating: 50.0, count: klines.count)
        for i in ((kPeriod - 1) + (slowing - 1))..<klines.count {
            let sum = rawK[(i - slowing + 1)...i].reduce(0.0, +)
            smoothedK[i] = sum / Double(slowing)
        }

        return smoothedK
    }

    /// Detects divergences across klines using 3-bar or 5-bar pivot fractals
    func detectDivergence(
        klines: [AstronacciKline],
        kPeriod: Int = 14,
        slowing: Int = 3,
        maxLookback: Int = 60
    ) -> AstronacciDivergenceResult {
        let closedKlines = klines.filter { $0.isClosed }
        guard closedKlines.count >= max(20, kPeriod + slowing + 5) else {
            return .none
        }

        let stochSeries = calculateStochasticSeries(kPeriod: kPeriod, slowing: slowing, klines: closedKlines)
        let totalCount = closedKlines.count
        let startIndex = max(2, totalCount - maxLookback)

        var troughs: [DivergencePivot] = []
        var crests: [DivergencePivot] = []

        // Scan 3-bar pivot fractals
        for i in startIndex..<(totalCount - 1) {
            let prev = closedKlines[i - 1]
            let curr = closedKlines[i]
            let next = closedKlines[i + 1]

            // Trough (Swing Low)
            if curr.low <= prev.low && curr.low < next.low {
                troughs.append(DivergencePivot(barIndex: i, price: curr.low, oscValue: stochSeries[i]))
            }

            // Crest (Swing High)
            if curr.high >= prev.high && curr.high > next.high {
                crests.append(DivergencePivot(barIndex: i, price: curr.high, oscValue: stochSeries[i]))
            }
        }

        let currentBarIndex = totalCount - 1

        // Evaluate Troughs (Bullish) - Prioritize most recent pairs
        if troughs.count >= 2 {
            for j in stride(from: troughs.count - 1, to: 0, by: -1) {
                let second = troughs[j]
                for k in stride(from: j - 1, through: 0, by: -1) {
                    let first = troughs[k]
                    // Minimum separation 3 bars
                    if (second.barIndex - first.barIndex) >= 3 {
                        let res = evaluateLowPivotsDivergence(first: first, second: second, currentBarIndex: currentBarIndex)
                        if res.type != .none {
                            return res
                        }
                    }
                }
            }
        }

        // Evaluate Crests (Bearish) - Prioritize most recent pairs
        if crests.count >= 2 {
            for j in stride(from: crests.count - 1, to: 0, by: -1) {
                let second = crests[j]
                for k in stride(from: j - 1, through: 0, by: -1) {
                    let first = crests[k]
                    if (second.barIndex - first.barIndex) >= 3 {
                        let res = evaluateHighPivotsDivergence(first: first, second: second, currentBarIndex: currentBarIndex)
                        if res.type != .none {
                            return res
                        }
                    }
                }
            }
        }

        return .none
    }
}
