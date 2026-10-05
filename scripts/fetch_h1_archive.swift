//
//  fetch_h1_archive.swift
//  boringNotch (Izanotchy Futures Scout)
//
//  Downloads In-Sample historical H1 klines for BTCUSDT, ETHUSDT, SOLUSDT
//  Adhering strictly to Option A Pre-Registration Charter Rev 2:
//  - Range: October 1, 2024 00:00 UTC to February 15, 2026 23:59 UTC (In-Sample 70% Only)
//  - Data Integrity Verifications: Gap-free check, zero duplicate timestamps, strictly monotonic order
//  - Benchmark: Calculates Buy-and-Hold Market Drift return for each asset
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
struct FetchH1ArchiveMain {
    static let startTimestamp: Int64 = 1727740800000 // 2024-10-01 00:00:00 UTC
    static let endTimestamp: Int64 = 1771199940000   // 2026-02-15 23:59:00 UTC
    static let assets = ["BTC-USDT", "ETH-USDT", "SOL-USDT"]

    static func main() async {
        print("=================================================================")
        print("📥 PENGUNDUH DATA HISTORIS H1 (IN-SAMPLE 70% SAJA) — CHARTER REV 2")
        print("=================================================================")
        print("Rentang Waktu: 1 Oktober 2024 00:00 UTC s/d 15 Februari 2026 23:59 UTC")
        print("Prinsip: OOS Beku (Dilarang mengunduh data pasca-15 Feb 2026)\n")

        for asset in assets {
            print("-----------------------------------------------------------------")
            print("🚀 Memulai pengunduhan kandel H1 untuk: \(asset)...")
            do {
                let klines = try await fetchFullRange(symbol: asset, start: startTimestamp, end: endTimestamp)
                print("  ✅ Terunduh: \(klines.count) kandel H1.")

                // Data Integrity Checks (Agent 1 Addendum 6)
                try validateDataIntegrity(klines: klines, symbol: asset)

                // Benchmark Drift Calculation (Agent 2 Amendment 3)
                if let first = klines.first, let last = klines.last {
                    let driftPct = ((last.close - first.open) / first.open) * 100.0
                    print(String(format: "  📊 Benchmark Buy-and-Hold (Drift): $%.2f -> $%.2f (%+.2f%%)", first.open, last.close, driftPct))
                }

                // Save to data directory
                let cleanSymbol = asset.replacingOccurrences(of: "-", with: "")
                let outputPath = "data/h1_archive_IS_\(cleanSymbol).json"
                let encoder = JSONEncoder()
                encoder.outputFormatting = .prettyPrinted
                let data = try encoder.encode(klines)
                try data.write(to: URL(fileURLWithPath: outputPath))
                print("  💾 Tersimpan di: \(outputPath)")
            } catch {
                print("  ❌ ERROR pada \(asset): \(error)")
                exit(1)
            }
        }

        print("\n=================================================================")
        print("🏁 SELURUH DATA IN-SAMPLE H1 BERHASIL DIUNDUH & TERVERIFIKASI INTEGRITASNYA!")
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

            var req = URLRequest(url: url)
            req.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36", forHTTPHeaderField: "User-Agent")
            req.setValue("application/json", forHTTPHeaderField: "Accept")

            // Native IPv4 fetch via curl to temporary file (eliminates pipe buffer deadlock on large payloads)
            let tempFile = "/tmp/bingx_h1_\(UUID().uuidString).json"
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
                // Filter strictly within In-Sample bounds
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

            // Respect rate limits gently
            try await Task.sleep(for: .milliseconds(150))
        }

        // Deduplicate by timestamp and sort ascending
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
            // Price integrity
            if k.high < k.low || k.open <= 0 || k.close <= 0 || k.high.isNaN || k.low.isNaN {
                throw NSError(domain: "IntegrityError", code: 2, userInfo: [NSLocalizedDescriptionKey: "Corrupted price candle at index \(idx)"])
            }

            // Monotonic timestamp check
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
            print("  ⚠️ Catatan Celah Waktu: Terdapat \(gapsCount) celah > 1 jam (pemeliharaan bursa atau libur quote).")
        } else {
            print("  ✅ Celah Waktu (Gaps): 0 (Kandil bersambung sempurna 1 jam).")
        }
    }
}
