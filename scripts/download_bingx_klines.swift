//
//  download_bingx_klines.swift
//  boringNotch (Izanotchy Futures Scout - Pilar 3)
//
//  Downloads 6 months of BTC-USDT Perpetual Futures klines from BingX Swap v2 API
//  Uses reverse pagination from nowMs backwards to startTargetMs.
//

import Foundation

struct BingXKlineRaw: Codable {
    let open: String
    let close: String
    let high: String
    let low: String
    let volume: String
    let time: Int64
}

struct BingXApiResponse: Codable {
    let code: Int
    let msg: String?
    let data: [BingXKlineRaw]?
}

public struct HistoricalKline: Codable {
    public let open: Double
    public let high: Double
    public let low: Double
    public let close: Double
    public let volume: Double
    public let timestamp: Int64
}

func fetchKlinesForInterval(interval: String, days: Int = 180, outputFilename: String) {
    let now = Date()
    let nowMs = Int64(now.timeIntervalSince1970 * 1000)
    let totalDurationMs = Int64(days) * 24 * 3600 * 1000
    let startTargetMs = nowMs - totalDurationMs
    
    print("\n=======================================================")
    print("📥 Mengunduh data BingX [\(interval)] untuk \(days) hari...")
    print("   Rentang Target: \(Date(timeIntervalSince1970: Double(startTargetMs)/1000.0)) s.d. \(now)")
    print("=======================================================")
    
    var allKlinesDict: [Int64: HistoricalKline] = [:]
    var currentEndMs = nowMs
    let limit = 1000
    
    var requestCount = 0
    let maxRequests = 300
    
    while currentEndMs > startTargetMs && requestCount < maxRequests {
        requestCount += 1
        let urlStr = "https://open-api.bingx.com/openApi/swap/v2/quote/klines?symbol=BTC-USDT&interval=\(interval)&endTime=\(currentEndMs)&limit=\(limit)"
        guard let url = URL(string: urlStr) else { break }
        
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 10.0
        
        let semaphore = DispatchSemaphore(value: 0)
        var fetchedData: [BingXKlineRaw] = []
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            defer { semaphore.signal() }
            guard let data = data, error == nil else { return }
            if let decoded = try? JSONDecoder().decode(BingXApiResponse.self, from: data),
               let rawBars = decoded.data {
                fetchedData = rawBars
            }
        }
        task.resume()
        _ = semaphore.wait(timeout: .now() + 12.0)
        
        if fetchedData.isEmpty {
            print("   ⚠️ Batch \(requestCount): Tidak ada data diterima untuk endTime=\(currentEndMs). Berhenti.")
            break
        }
        
        var addedThisBatch = 0
        var minTimeInBatch: Int64 = Int64.max
        
        for raw in fetchedData {
            guard let o = Double(raw.open),
                  let h = Double(raw.high),
                  let l = Double(raw.low),
                  let c = Double(raw.close),
                  let v = Double(raw.volume) else { continue }
            
            if raw.time < minTimeInBatch {
                minTimeInBatch = raw.time
            }
            
            if allKlinesDict[raw.time] == nil {
                allKlinesDict[raw.time] = HistoricalKline(open: o, high: h, low: l, close: c, volume: v, timestamp: raw.time)
                addedThisBatch += 1
            }
        }
        
        let progressDate = Date(timeIntervalSince1970: Double(minTimeInBatch)/1000.0)
        print("   Batch \(requestCount): +\(addedThisBatch) bar baru (Total unik: \(allKlinesDict.count)) -> Timestamp terlama: \(progressDate)")
        
        if minTimeInBatch >= currentEndMs || addedThisBatch == 0 {
            print("   ⚠️ Tidak ada bar lebih lama. Mencapai batas bursa.")
            break
        }
        
        if minTimeInBatch <= startTargetMs {
            print("   🎯 Target waktu 180 hari yang lalu (\(Date(timeIntervalSince1970: Double(startTargetMs)/1000.0))) telah tercapai!")
            break
        }
        
        // Mundurkan endTime ke 1 milidetik sebelum kandel terlama di batch ini
        currentEndMs = minTimeInBatch - 1
        
        // Delay 100ms agar ramah rate-limit
        usleep(100000)
    }
    
    // Urutkan kline secara kronologis (ascending)
    var sortedKlines = Array(allKlinesDict.values)
    sortedKlines.sort { $0.timestamp < $1.timestamp }
    
    print("✅ Berhasil mengunduh total \(sortedKlines.count) kandel untuk timeframe [\(interval)].")
    if let first = sortedKlines.first, let last = sortedKlines.last {
        print("   Dari : \(Date(timeIntervalSince1970: Double(first.timestamp)/1000.0))")
        print("   Sampai: \(Date(timeIntervalSince1970: Double(last.timestamp)/1000.0))")
    }
    
    // Simpan ke disk (format JSON kompak untuk efisiensi penyimpanan & loading super cepat)
    let outputPath = outputFilename
    let encoder = JSONEncoder()
    if let encodedData = try? encoder.encode(sortedKlines) {
        do {
            try encodedData.write(to: URL(fileURLWithPath: outputPath))
            let sizeMb = Double(encodedData.count) / (1024.0 * 1024.0)
            print("💾 Tersimpan di: \(outputPath) (\(String(format: "%.2f", sizeMb)) MB)")
        } catch {
            print("❌ Gagal menyimpan berkas: \(error)")
        }
    }
}

// Eksekusi utama
let baseDir = "data/historical_klines"
try? FileManager.default.createDirectory(atPath: baseDir, withIntermediateDirectories: true)

fetchKlinesForInterval(interval: "1h", days: 180, outputFilename: "\(baseDir)/bingx_btcusdt_1h.json")
fetchKlinesForInterval(interval: "15m", days: 180, outputFilename: "\(baseDir)/bingx_btcusdt_15m.json")
fetchKlinesForInterval(interval: "5m", days: 180, outputFilename: "\(baseDir)/bingx_btcusdt_5m.json")

print("\n🎉 SEMUA DATA HISTORIS 6 BULAN RESMI TERUNDUH & TERSIMPAN.")
