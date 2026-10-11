//
//  AstronacciQuasimodoEngine.swift
//  izaNotch
//
//  Created for Izanotchy - Advanced Astronacci Foundations (Pillar 9: Pola Quasimodo / Over-Under)
//  Detects Left Shoulder, Head (Liquidity Sweep), Break of Structure (BOS), and Left Shoulder Retest zone.
//  Strictly pure-mathematical, zero external dependencies, thread-safe & Sendable.
//

import Foundation

public enum QMType: String, Equatable, Sendable {
    case bullish = "Bullish Quasimodo (Over-Under Bottom Reversal)"
    case bearish = "Bearish Quasimodo (Over-Under Top Reversal)"
    case none = "Tidak Ada Pola Quasimodo"
}

public struct AstronacciQMResult: Equatable, Sendable {
    public let type: QMType
    public let leftShoulderPrice: Double
    public let description: String

    public init(
        type: QMType,
        leftShoulderPrice: Double,
        description: String
    ) {
        self.type = type
        self.leftShoulderPrice = leftShoulderPrice
        self.description = description
    }

    public static let none = AstronacciQMResult(
        type: .none,
        leftShoulderPrice: 0.0,
        description: "Tidak terdeteksi pola Quasimodo pada struktur kandel."
    )
}

struct AstronacciQuasimodoEngine: Sendable {
    init() {}

    /// Evaluates 4 specific pivot points to determine if they form a valid Quasimodo pattern
    func evaluatePattern(
        p1Price: Double, // Left Shoulder (Low 1 if bullish, High 1 if bearish)
        p1Index: Int,
        p2Price: Double, // Intermediate Swing (High 1 if bullish, Low 1 if bearish)
        p2Index: Int,
        p3Price: Double, // Head (Low 2 if bullish, High 2 if bearish)
        p3Index: Int,
        p4Price: Double, // BOS (High 2 if bullish, Low 2 if bearish)
        p4Index: Int,
        currentPrice: Double,
        atr: Double,
        isBullishStructure: Bool
    ) -> AstronacciQMResult {
        guard p1Index < p2Index && p2Index < p3Index && p3Index < p4Index else {
            return .none
        }

        let retestTolerance = max(atr * 0.5, p1Price * 0.003)

        if isBullishStructure {
            // Bullish QM: Low1 (LS) -> High1 -> Low2 (Head < Low1) -> High2 (BOS > High1)
            guard p3Price < p1Price else { return .none } // Head must sweep liquidity below Left Shoulder
            guard p4Price > p2Price else { return .none } // BOS must break above High 1

            let impulseRange = p4Price - p3Price
            guard impulseRange > 0 else { return .none }

            // Fibonacci retracement of Head (P3) to BOS (P4)
            // Retracement levels measured from P4 downwards:
            // 50% = P4 - 0.50 * Range = P3 + 0.50 * Range
            // 61.8% = P4 - 0.618 * Range = P3 + 0.382 * Range
            // 78.6% = P4 - 0.786 * Range = P3 + 0.214 * Range
            let gpHigh = p4Price - 0.50 * impulseRange
            let _ = p4Price - 0.618 * impulseRange
            let oteLow = p4Price - 0.786 * impulseRange

            let isLeftShoulderInGP = (p1Price >= oteLow - retestTolerance && p1Price <= gpHigh + retestTolerance)
            let isRetestingNow = abs(currentPrice - p1Price) <= retestTolerance
            let dist = abs(currentPrice - p1Price)

            let retestDesc = isRetestingNow ? "Harga saat ini sedang menguji (re-test) level Left Shoulder." : "Mendekati zona re-test Left Shoulder (jarak $\(String(format: "%.2f", dist)))."
            let desc = "Bullish Quasimodo: Left Shoulder $\(String(format: "%.2f", p1Price)), Head (Sweep) $\(String(format: "%.2f", p3Price)), BOS $\(String(format: "%.2f", p4Price)). Invalidation: $\(String(format: "%.2f", p3Price)). \(retestDesc)"

            return AstronacciQMResult(
                type: .bullish,
                leftShoulderPrice: p1Price,
                description: desc
            )
        } else {
            // Bearish QM: High1 (LS) -> Low1 -> High2 (Head > High1) -> Low2 (BOS < Low1)
            guard p3Price > p1Price else { return .none } // Head must sweep liquidity above Left Shoulder
            guard p4Price < p2Price else { return .none } // BOS must break below Low 1

            let impulseRange = p3Price - p4Price
            guard impulseRange > 0 else { return .none }

            let gpLow = p4Price + 0.50 * impulseRange
            let _ = p4Price + 0.618 * impulseRange
            let oteHigh = p4Price + 0.786 * impulseRange

            let isLeftShoulderInGP = (p1Price <= oteHigh + retestTolerance && p1Price >= gpLow - retestTolerance)
            let isRetestingNow = abs(currentPrice - p1Price) <= retestTolerance
            let dist = abs(currentPrice - p1Price)

            let retestDesc = isRetestingNow ? "Harga saat ini sedang menguji (re-test) level Left Shoulder." : "Mendekati zona re-test Left Shoulder (jarak $\(String(format: "%.2f", dist)))."
            let desc = "Bearish Quasimodo: Left Shoulder $\(String(format: "%.2f", p1Price)), Head (Sweep) $\(String(format: "%.2f", p3Price)), BOS $\(String(format: "%.2f", p4Price)). Invalidation: $\(String(format: "%.2f", p3Price)). \(retestDesc)"

            return AstronacciQMResult(
                type: .bearish,
                leftShoulderPrice: p1Price,
                description: desc
            )
        }
    }

    private struct InternalPivot {
        let index: Int
        let price: Double
        let isHigh: Bool
    }

    /// Detects Quasimodo pattern from a series of closed klines
    func detectQuasimodo(
        klines: [AstronacciKline],
        currentPrice: Double,
        atr: Double,
        lookbackBars: Int = 50
    ) -> AstronacciQMResult {
        let closedKlines = klines.filter { $0.isClosed }
        guard closedKlines.count >= 15 else { return .none }

        let totalCount = closedKlines.count
        let startIndex = max(2, totalCount - lookbackBars)

        // Find alternating pivots using 3-bar fractals
        var rawPivots: [InternalPivot] = []
        for i in startIndex..<(totalCount - 1) {
            let prev = closedKlines[i - 1]
            let curr = closedKlines[i]
            let next = closedKlines[i + 1]

            if curr.high >= prev.high && curr.high > next.high {
                rawPivots.append(InternalPivot(index: i, price: curr.high, isHigh: true))
            }
            if curr.low <= prev.low && curr.low < next.low {
                rawPivots.append(InternalPivot(index: i, price: curr.low, isHigh: false))
            }
        }

        // Clean pivots to ensure strict alternation (High, Low, High, Low...)
        guard rawPivots.count >= 4 else { return .none }

        var alternating: [InternalPivot] = []
        for p in rawPivots {
            if let last = alternating.last {
                if last.isHigh == p.isHigh {
                    // Same type: keep the more extreme one
                    if p.isHigh && p.price > last.price {
                        alternating[alternating.count - 1] = p
                    } else if !p.isHigh && p.price < last.price {
                        alternating[alternating.count - 1] = p
                    }
                } else {
                    alternating.append(p)
                }
            } else {
                alternating.append(p)
            }
        }

        guard alternating.count >= 4 else { return .none }

        // Test 4 consecutive pivots starting from the most recent
        for i in stride(from: alternating.count - 4, through: 0, by: -1) {
            let p1 = alternating[i]
            let p2 = alternating[i + 1]
            let p3 = alternating[i + 2]
            let p4 = alternating[i + 3]

            // Check Bullish QM: Low -> High -> Low -> High
            if !p1.isHigh && p2.isHigh && !p3.isHigh && p4.isHigh {
                let res = evaluatePattern(
                    p1Price: p1.price,
                    p1Index: p1.index,
                    p2Price: p2.price,
                    p2Index: p2.index,
                    p3Price: p3.price,
                    p3Index: p3.index,
                    p4Price: p4.price,
                    p4Index: p4.index,
                    currentPrice: currentPrice,
                    atr: atr,
                    isBullishStructure: true
                )
                if res.type != .none {
                    return res
                }
            }

            // Check Bearish QM: High -> Low -> High -> Low
            if p1.isHigh && !p2.isHigh && p3.isHigh && !p4.isHigh {
                let res = evaluatePattern(
                    p1Price: p1.price,
                    p1Index: p1.index,
                    p2Price: p2.price,
                    p2Index: p2.index,
                    p3Price: p3.price,
                    p3Index: p3.index,
                    p4Price: p4.price,
                    p4Index: p4.index,
                    currentPrice: currentPrice,
                    atr: atr,
                    isBullishStructure: false
                )
                if res.type != .none {
                    return res
                }
            }
        }

        return .none
    }
}
