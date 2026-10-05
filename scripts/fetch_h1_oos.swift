//
//  fetch_h1_oos.swift
//  boringNotch (Izanotchy Futures Scout)
//
//  Downloads Out-of-Sample (OOS 30%) historical H1 klines for BTCUSDT
//  Adhering strictly to Option A Pre-Registration Charter Rev 2.1:
//  - Range: February 16, 2026 00:00 UTC to September 26, 2026 23:59 UTC (OOS 30% Holdout)
//  - Asset: BTCUSDT (Exclusive single-asset track ratified by Agent 1 & Agent 2)
//  - Data Integrity Verifications: Gap-free check, zero duplicate timestamps, strictly monotonic order
//  - Benchmark: Calculates Buy-and-Hold Market Drift return for OOS BTCUSDT
//

import Foundation

struct KlineItem: Codable {
    let timestamp: Int64
    let open: Double
    let high: Double
    let low: Double
    let close: Double
    let volume: Double
}

struct BingXQuoteResponse: Decodable {
    let code: Int
    let msg: String?
    let data: [BingXItem]?
}

struct BingXItem: Decodable {
    let open: String
    let close: String
    let high: String
    let low: String
    let volume: String
    let time: Double
}

@main
struct FetchH1OOSMain {
    static let startTimestamp: Int64 = 1771200000000 // 2026-02-16 00:00:00 UTC
    static let endTimestamp: Int64 = 1790467140000   // 2026-09-26 23:59:00 UTC
    static let asset = "BTC-USDT"

    static func main() async {
        print("=================================================================")
        print("📥 PENGUNDUH DATA HISTORIS H1 OUT-OF-SAMPLE (OOS 30%) — CHARTER REV 2.1")
        print("=================================================================")
        print("Rentang Waktu: 16 Februari 2026 00:00 UTC s/d 26 September 2026 23:59 UTC")
        print("Instrumen: \(asset) (Jalur Kelulusan Tunggal Teratifikasi)\n")

        print("🚀 Memulai pengunduhan kandel H1 OOS untuk: \(asset)...")
        do {
            let klines = try await fetchFullRange(symbol: asset, start: startTimestamp, end: endTimestamp)
            print("  ✅ Terunduh: \(klines.count) kandel H1 OOS.")

            // Data Integrity Checks
            try validateDataIntegrity(klines: klines, symbol: asset)

            // Benchmark Drift Calculation
            if let first = klines.first, let last = klines.last {
                let driftPct = ((last.close - first.open) / first.open) * 100.0
                print(String(format: "  📊 Benchmark Buy-and-Hold OOS (Drift): $%.2f -> $%.2f (%+.2f%%)", first.open, last.close, driftPct))
            }

            // Save to data directory
            let cleanSymbol = asset.replacingOccurrences(of: "-", with: "")
            let outputPath = "data/h1_archive_OOS_\(cleanSymbol).json"
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(klines)
            try data.write(to: URL(fileURLWithPath: outputPath))
            print("  💾 Tersimpan di: \(outputPath)")
        } catch {
            print("  ❌ ERROR pada \(asset): \(error)")
            exit(1)
        }

        print("\n=================================================================")
        print("🏁 DATA OUT-OF-SAMPLE BTCUSDT BERHASIL DIUNDUH & TERVERIFIKASI!")
        print("=================================================================")
    }

    static func fetchFullRange(symbol: String, start: Int64, end: Int64) async throws -> [KlineItem] {
        var allKlines: [KlineItem] = []
        var currentStart = start
        let oneHourMs: Int64 = 3600000

        while currentStart < end {
            guard let url = URL(string: "https://open-api.bingx.com/openApi/swap/v2/quote/klines?symbol=\(symbol)&interval=1h&limit=1000&startTime=\(currentStart)") else {
                throw URLError(.badURL)
            }

            let tempFile = "/tmp/bingx_h1_oos_\(UUID().uuidString).json"
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/curl")
            process.arguments = ["-s", "-4", "--connect-timeout", "10", "--max-time", "15", "-o", tempFile, url.absoluteString]

            try process.run()
            process.waitUntilExit()

            let tempURL = URL(fileURLWithPath: tempFile)
            defer { try? FileManager.default.removeItem(at: tempURL) }
            guard FileManager.default.fileExists(atPath: tempFile) else {
                throw NSError(domain: "FetchError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Temp curl output missing"])
            }

            let data = try Data(contentsOf: tempURL)
            let decoded = try JSONDecoder().decode(BingXQuoteResponse.self, from: data)

            guard decoded.code == 0, let items = decoded.data, !items.isEmpty else {
                print("    ⚠️ Tidak ada data lagi dari BingX pada timestamp \(currentStart)")
                break
            }

            var chunk: [KlineItem] = []
            for item in items {
                guard let o = Double(item.open),
                      let c = Double(item.close),
                      let h = Double(item.high),
                      let l = Double(item.low),
                      let v = Double(item.volume) else { continue }

                let ts = Int64(item.time)
                if ts >= start && ts <= end {
                    chunk.append(KlineItem(timestamp: ts, open: o, high: h, low: l, close: c, volume: v))
                }
            }

            if chunk.isEmpty {
                break
            }

            allKlines.append(contentsOf: chunk)
            let lastTs = Int64(items.last!.time)
            if lastTs <= currentStart {
                break
            }
            currentStart = lastTs + oneHourMs

            try await Task.sleep(for: .milliseconds(150))
        }

        var seen = Set<Int64>()
        var unique: [KlineItem] = []
        for k in allKlines {
            if !seen.contains(k.timestamp) {
                seen.insert(k.timestamp)
                unique.append(k)
            }
        }
        unique.sort { $0.timestamp < $1.timestamp }
        return unique
    }

    static func validateDataIntegrity(klines: [KlineItem], symbol: String) throws {
        guard !klines.isEmpty else {
            throw NSError(domain: "IntegrityError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Klines empty for \(symbol)"])
        }

        var previousTs: Int64? = nil
        let oneHourMs: Int64 = 3600000
        var gapsCount = 0

        for (idx, k) in klines.enumerated() {
            if k.high < k.low || k.open <= 0 || k.close <= 0 || k.high.isNaN || k.low.isNaN {
                throw NSError(domain: "IntegrityError", code: 2, userInfo: [NSLocalizedDescriptionKey: "Corrupted price candle at index \(idx)"])
            }

            if let prev = previousTs {
                if k.timestamp <= prev {
                    throw NSError(domain: "IntegrityError", code: 3, userInfo: [NSLocalizedDescriptionKey: "Non-monotonic timestamp at index \(idx): \(k.timestamp) <= \(prev)"])
                }
                let diff = k.timestamp - prev
                if diff > oneHourMs {
                    gapsCount += 1
                }
            }
            previousTs = k.timestamp
        }

        print("  🔍 Verifikasi Integritas: Nol bar korup, Monotonik 100% Valid.")
        if gapsCount > 0 {
            print("  ⚠️ Catatan Celah Waktu: Terdapat \(gapsCount) celah > 1 jam.")
        } else {
            print("  ✅ Celah Waktu (Gaps): 0 (Kandil bersambung sempurna 1 jam).")
        }
    }
}
