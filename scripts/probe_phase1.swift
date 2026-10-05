//
//  probe_phase1.swift
//  scripts
//
//  Skrip Verifikasi Pengguna untuk Fase 1 (Pre-Flight Gate & Layer-0 Readiness)
//  Menjalankan aktivasi TradingView, memeriksa Layer 0 WindowServer, dan mengambil snapshot.
//

import Cocoa
import ApplicationServices

print("==================================================================")
print("🧪 UJI MANDIRI PENGGUNA: FASE 1 (PRE-FLIGHT & WINDOWSERVER GATE)")
print("==================================================================")

// 1. Memanggil aktivasi TradingView
print("\n[1/3] Mengaktifkan TradingView ke layar depan...")
let appPath = "/Applications/TradingView.app"
let proc = Process()
proc.executableURL = URL(fileURLWithPath: "/usr/bin/open")
proc.arguments = ["-a", appPath]
try? proc.run()

let script = """
tell application "TradingView"
    activate
    reopen
end tell
tell application "System Events"
    tell process "TradingView"
        set frontmost to true
    end tell
end tell
"""
if let appleScript = NSAppleScript(source: script) {
    var err: NSDictionary?
    appleScript.executeAndReturnError(&err)
}

Thread.sleep(forTimeInterval: 0.5)

// 2. Memeriksa status frontmost dan WindowServer Layer 0
print("[2/3] Memeriksa status Layer 0 dan dimensi jendela di WindowServer...")
let runningApps = NSWorkspace.shared.runningApplications
let isFront = runningApps.first { $0.localizedName == "TradingView" }?.isActive ?? false

let wins = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
var foundLayer0 = false
var winId: Int = 0
var boundsDict: [String: Any] = [:]
var winTitle: String = ""

for w in wins {
    let owner = w[kCGWindowOwnerName as String] as? String ?? ""
    let layer = w[kCGWindowLayer as String] as? Int ?? -1
    if owner == "TradingView" && layer == 0 {
        if let b = w[kCGWindowBounds as String] as? [String: Any],
           let width = b["Width"] as? CGFloat,
           let height = b["Height"] as? CGFloat,
           width >= 600 && height >= 400 {
            foundLayer0 = true
            winId = w[kCGWindowNumber as String] as? Int ?? 0
            boundsDict = b
            winTitle = w[kCGWindowName as String] as? String ?? ""
            break
        }
    }
}

print("\n--- HASIL PEMERIKSAAN SISTEM ---")
print("• TradingView Terangkat ke Depan (Frontmost) : \(isFront ? "✅ YA" : "❌ TIDAK")")
print("• Jendela Utama Terdaftar di Layer 0         : \(foundLayer0 ? "✅ YA" : "❌ TIDAK")")
print("• Window ID                                 : \(winId)")
print("• Dimensi Jendela                           : \(boundsDict["Width"] ?? 0) x \(boundsDict["Height"] ?? 0) pt")
print("• Judul Jendela Saat Ini                    : '\(winTitle)'")

// 3. Mengambil tangkapan layar tertarget jendela TradingView
if foundLayer0 && winId > 0 {
    print("\n[3/3] Mengambil tangkapan layar bukti jendela (Window ID \(winId))...")
    let cap = Process()
    cap.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
    cap.arguments = ["-x", "-l", "\(winId)", "/tmp/phase1_verified_window.png"]
    try? cap.run()
    cap.waitUntilExit()
    print("📸 Tangkapan layar tersimpan di: /tmp/phase1_verified_window.png")
}

print("==================================================================")
if isFront && foundLayer0 {
    print("🎉 KESIMPULAN: FASE 1 LOLOS 100% (TRADINGVIEW SIAP BERINTERAKSI)")
    print("Buka bukti visual dengan perintah: open /tmp/phase1_verified_window.png")
} else {
    print("❌ KESIMPULAN: FASE 1 GAGAL")
}
print("==================================================================")
