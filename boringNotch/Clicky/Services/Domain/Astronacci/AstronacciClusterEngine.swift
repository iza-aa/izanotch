//
//  AstronacciClusterEngine.swift
//  boringNotch (Izanotchy Futures Scout)
//
//  Mathematical Key Reversal Zone (KRZ) & Fibonacci Cluster Engine
//  Canon (Prof. Dr. Gema Goeyardi - The Art of Fibonacci Trading):
//  - Confluence between Major Swing (H1 61.8%) and Micro Swing (M15 50.0%, 61.8%, 78.6%)
//  - Dynamic Tolerance: <= 0.25 * ATR(14) of M15
//  - Pure Analyst Layer (Presentation & Chart Overlay, Zero Core Engine Mutation)
//

import Foundation

public struct FibonacciClusterResult: Sendable, Codable, Equatable {
    public let hasCluster: Bool
    public let krzMin: Double
    public let krzMax: Double
    public let h1LevelName: String
    public let h1Price: Double
    public let m15LevelName: String
    public let m15Price: Double
    public let distance: Double
    public let toleranceUsed: Double
    public let label: String

    public static let empty = FibonacciClusterResult(
        hasCluster: false,
        krzMin: 0,
        krzMax: 0,
        h1LevelName: "",
        h1Price: 0,
        m15LevelName: "",
        m15Price: 0,
        distance: 0,
        toleranceUsed: 0,
        label: "Tidak ada Fibonacci Cluster KRZ terdeteksi"
    )
}

public struct AstronacciClusterEngine: Sendable {

    /// Direct level evaluator with dynamic ATR tolerance
    public static func evaluateLevels(
        h1Levels: [(name: String, price: Double)],
        m15Levels: [(name: String, price: Double)],
        atr14M15: Double
    ) -> FibonacciClusterResult {
        guard atr14M15 > 0 else {
            return .empty
        }

        let tolerance = 0.25 * atr14M15
        var bestMatch: (h1Name: String, h1Price: Double, m15Name: String, m15Price: Double, dist: Double)? = nil

        for h1 in h1Levels {
            guard h1.price > 0 else { continue }
            for m15 in m15Levels {
                guard m15.price > 0 else { continue }
                let dist = abs(h1.price - m15.price)
                if dist <= tolerance {
                    if let existing = bestMatch {
                        if dist < existing.dist {
                            bestMatch = (h1.name, h1.price, m15.name, m15.price, dist)
                        }
                    } else {
                        bestMatch = (h1.name, h1.price, m15.name, m15.price, dist)
                    }
                }
            }
        }

        guard let match = bestMatch else {
            return .empty
        }

        let pMin = min(match.h1Price, match.m15Price)
        let pMax = max(match.h1Price, match.m15Price)

        let isExtension = match.h1Name.contains("61.8%") && match.m15Name.contains("61.8%")
        let extTag = isExtension ? " (Perluasan Konfluensi)" : ""
        let label = "KRZ Cluster Terkonfirmasi\(extTag): \(match.h1Name) (\(formatNum(match.h1Price))) ∩ \(match.m15Name) (\(formatNum(match.m15Price))) [Rentang: \(formatNum(pMin)) – \(formatNum(pMax)), Selisih $\(formatNum(match.dist)) ≤ 0.25×ATR ($\(formatNum(tolerance)))]"

        return FibonacciClusterResult(
            hasCluster: true,
            krzMin: pMin,
            krzMax: pMax,
            h1LevelName: match.h1Name,
            h1Price: match.h1Price,
            m15LevelName: match.m15Name,
            m15Price: match.m15Price,
            distance: match.dist,
            toleranceUsed: tolerance,
            label: label
        )
    }

    /// Evaluates full multi-timeframe kline series to detect Key Reversal Zone cluster
    public static func evaluateConfluence(
        klinesH1: [AstronacciKline],
        klinesM15: [AstronacciKline],
        atr14M15: Double,
        regime: AstronacciRegime
    ) -> FibonacciClusterResult {
        guard atr14M15 > 0, regime != .choppy else {
            return .empty
        }

        let engine = AstronacciDeterministicEngine()

        // 1. Detect Pivot Fractals for H1
        guard let h1Pivots = engine.detect5BarPivotFractals(klines: klinesH1) else {
            return .empty
        }

        // 2. Detect Pivot Fractals for M15
        guard let m15Pivots = engine.detect5BarPivotFractals(klines: klinesM15) else {
            return .empty
        }

        let isBullish = (regime == .bullish)

        // 3. Compute H1 Fib 61.8%
        let h1Range = h1Pivots.swingHigh - h1Pivots.swingLow
        guard h1Range > 0 else { return .empty }

        let h1Fib618: Double = isBullish
            ? h1Pivots.swingHigh - (h1Range * 0.618)
            : h1Pivots.swingLow + (h1Range * 0.618)

        let h1Levels: [(String, Double)] = [
            ("H1 61.8%", h1Fib618)
        ]

        // 4. Compute M15 Fib Retracement Candidates (50.0%, 61.8%, 78.6%)
        let m15Range = m15Pivots.swingHigh - m15Pivots.swingLow
        guard m15Range > 0 else { return .empty }

        let m15Fib500: Double = isBullish ? m15Pivots.swingHigh - (m15Range * 0.500) : m15Pivots.swingLow + (m15Range * 0.500)
        let m15Fib618: Double = isBullish ? m15Pivots.swingHigh - (m15Range * 0.618) : m15Pivots.swingLow + (m15Range * 0.618)
        let m15Fib786: Double = isBullish ? m15Pivots.swingHigh - (m15Range * 0.786) : m15Pivots.swingLow + (m15Range * 0.786)

        let m15Levels: [(String, Double)] = [
            ("M15 50.0%", m15Fib500),
            ("M15 61.8%", m15Fib618),
            ("M15 78.6%", m15Fib786)
        ]

        return evaluateLevels(h1Levels: h1Levels, m15Levels: m15Levels, atr14M15: atr14M15)
    }

    private static func formatNum(_ val: Double) -> String {
        if val >= 1000 {
            return String(format: "%.1f", val)
        } else if val >= 1 {
            return String(format: "%.2f", val)
        } else if val >= 0.01 {
            return String(format: "%.4f", val)
        } else {
            return String(format: "%.6f", val)
        }
    }
}
