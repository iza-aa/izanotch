import Foundation

public struct AudioLevelProcessor: Sendable {
    public static func calculateNormalizedLevels(from samples: [Float], barCount: Int = 6) -> [CGFloat] {
        guard !samples.isEmpty else {
            return Array(repeating: 0.15, count: barCount)
        }

        let sum = samples.reduce(0.0) { $0 + ($1 * $1) }
        let rms = sqrt(sum / Float(samples.count))
        let clampedRMS = min(1.0, max(0.0, rms * 3.5))

        var bars: [CGFloat] = []
        for i in 0..<barCount {
            let variance = Float(sin(Double(i) * 0.8 + Double(clampedRMS))) * 0.10
            let barHeight = max(0.12, min(1.0, CGFloat(clampedRMS + variance)))
            bars.append(barHeight)
        }

        return bars
    }
}
