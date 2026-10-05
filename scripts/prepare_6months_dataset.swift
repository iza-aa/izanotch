//
//  prepare_6months_dataset.swift
//  boringNotch (Izanotchy Futures Scout - Pilar 3)
//
//  Prepares continuous 6-month historical dataset (2026-04-01 to 2026-09-26)
//  for BTCUSDT Futures (1h, 15m, 5m).
//

import Foundation

struct KlineRecord: Codable {
    let open: Double
    let high: Double
    let low: Double
    let close: Double
    let volume: Double
    let timestamp: Int64
}

let intervals = ["1h", "15m", "5m"]
let months = ["2026-04", "2026-05", "2026-06", "2026-07", "2026-08"]
let sepDays = (1...25).map { String(format: "2026-09-%02d", $0) }

let baseDir = "data/historical_klines"
try? FileManager.default.createDirectory(atPath: baseDir, withIntermediateDirectories: true)
let tempDir = "/tmp/futures_scout_zips"
try? FileManager.default.createDirectory(atPath: tempDir, withIntermediateDirectories: true)

print("=======================================================")
print("🌐 Menyiapkan Dataset Historis 6 Bulan BTCUSDT Futures")
print("   Periode: 1 April 2026 s.d. 26 September 2026 (~180 Hari)")
print("=======================================================")

for interval in intervals {
    print("\n📦 Memproses timeframe [\(interval)]...")
    var recordsDict: [Int64: KlineRecord] = [:]
    
    // 1. Download & parse Monthly Archives (Apr - Aug 2026)
    for month in months {
        let fileName = "BTCUSDT-\(interval)-\(month).zip"
        let urlStr = "https://data.binance.vision/data/futures/um/monthly/klines/BTCUSDT/\(interval)/\(fileName)"
        let zipPath = "\(tempDir)/\(fileName)"
        
        // Download jika belum ada
        if !FileManager.default.fileExists(atPath: zipPath) {
            guard let url = URL(string: urlStr), let data = try? Data(contentsOf: url) else {
                print("   ⚠️ Gagal mengunduh: \(fileName)")
                continue
            }
            try? data.write(to: URL(fileURLWithPath: zipPath))
        }
        
        // Ekstrak via unzip -p pipe
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        process.arguments = ["-p", zipPath]
        let pipe = Pipe()
        process.standardOutput = pipe
        try? process.run()
        let csvData = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        
        guard let csvStr = String(data: csvData, encoding: .utf8) else { continue }
        let lines = csvStr.split(separator: "\n")
        var count = 0
        for line in lines {
            if line.starts(with: "open_time") { continue }
            let parts = line.split(separator: ",")
            if parts.count >= 6,
               let t = Int64(parts[0]),
               let o = Double(parts[1]),
               let h = Double(parts[2]),
               let l = Double(parts[3]),
               let c = Double(parts[4]),
               let v = Double(parts[5]) {
                recordsDict[t] = KlineRecord(open: o, high: h, low: l, close: c, volume: v, timestamp: t)
                count += 1
            }
        }
        print("   ✅ Bulan \(month): \(count) bar dimuat.")
    }
    
    // 2. Download & parse Daily Archives for September (1 - 25 Sept 2026)
    var sepCount = 0
    for day in sepDays {
        let fileName = "BTCUSDT-\(interval)-\(day).zip"
        let urlStr = "https://data.binance.vision/data/futures/um/daily/klines/BTCUSDT/\(interval)/\(fileName)"
        let zipPath = "\(tempDir)/\(fileName)"
        
        if !FileManager.default.fileExists(atPath: zipPath) {
            guard let url = URL(string: urlStr), let data = try? Data(contentsOf: url) else { continue }
            try? data.write(to: URL(fileURLWithPath: zipPath))
        }
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        process.arguments = ["-p", zipPath]
        let pipe = Pipe()
        process.standardOutput = pipe
        try? process.run()
        let csvData = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        
        guard let csvStr = String(data: csvData, encoding: .utf8) else { continue }
        let lines = csvStr.split(separator: "\n")
        for line in lines {
            if line.starts(with: "open_time") { continue }
            let parts = line.split(separator: ",")
            if parts.count >= 6,
               let t = Int64(parts[0]),
               let o = Double(parts[1]),
               let h = Double(parts[2]),
               let l = Double(parts[3]),
               let c = Double(parts[4]),
               let v = Double(parts[5]) {
                recordsDict[t] = KlineRecord(open: o, high: h, low: l, close: c, volume: v, timestamp: t)
                sepCount += 1
            }
        }
    }
    print("   ✅ September 1-25: \(sepCount) bar harian dimuat.")
    
    // 3. Tambahkan bar hari ini (26 Sept 2026) dari BingX live cache yang sudah ada
    let bingXPath = "\(baseDir)/bingx_btcusdt_\(interval).json"
    if let data = try? Data(contentsOf: URL(fileURLWithPath: bingXPath)),
       let bingXRecords = try? JSONDecoder().decode([KlineRecord].self, from: data) {
        var todayCount = 0
        for b in bingXRecords {
            // Ambil bar tanggal 26 Sept (timestamp >= 1790380800000)
            if b.timestamp >= 1790380800000 {
                recordsDict[b.timestamp] = b
                todayCount += 1
            }
        }
        print("   ✅ 26 September Live: \(todayCount) bar dimuat.")
    }
    
    // 4. Urutkan secara kronologis
    var sorted = Array(recordsDict.values)
    sorted.sort { $0.timestamp < $1.timestamp }
    
    print("   📊 Total kandel [\(interval)]: \(sorted.count) bar")
    if let first = sorted.first, let last = sorted.last {
        let d1 = Date(timeIntervalSince1970: Double(first.timestamp)/1000.0)
        let d2 = Date(timeIntervalSince1970: Double(last.timestamp)/1000.0)
        print("      Rentang: \(d1) s.d. \(d2)")
    }
    
    // Simpan ke output final
    let outPath = "\(baseDir)/btcusdt_\(interval)_6m.json"
    let encoder = JSONEncoder()
    if let encoded = try? encoder.encode(sorted) {
        try? encoded.write(to: URL(fileURLWithPath: outPath))
        let mb = Double(encoded.count) / (1024.0 * 1024.0)
        print("   💾 Disimpan di: \(outPath) (\(String(format: "%.2f", mb)) MB)")
    }
}

print("\n🎉 DATASET 6 BULAN (1H, 15M, 5M) LENGKAP & SIAP DIGUNAKAN!")
