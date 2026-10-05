//
//  probe_phase2.swift
//  scripts
//
//  Skrip Verifikasi Pengguna untuk Fase 2 (Closed-Loop CUA Symbol Switching)
//  Memerintahkan Izanotchy yang sedang berjalan untuk menerbangkan CuaDrive Action Cursor,
//  mengeklik Symbol Search Pill secara presisi, mengetik simbol target, dan memverifikasi
//  perubahan judul jendela di WindowServer tanpa membajak mouse fisik pengguna.
//

import Cocoa
import ApplicationServices

let targetSymbol = CommandLine.arguments.count > 1 ? CommandLine.arguments[1].uppercased() : "ETH"

print("==================================================================")
print("🧪 UJI MANDIRI PENGGUNA: FASE 2 (CUA DUAL-CURSOR SYMBOL SWITCHING)")
print("==================================================================")
print("Target Simbol: \(targetSymbol)")
print("")
print("👀 PERHATIKAN LAYAR ANDA:")
print("1. CursorAssist Clicky (kursor pendamping permanen) TETAP berada di sisi mouse Anda.")
print("2. CuaDrive Action Cursor (kursor kerja neon cyan) MUNCUL secara ephemeral,")
print("   terbang halus (60fps Dubins curve) menuju toolbar Symbol Search TradingView,")
print("   menampilkan badge 'Cari Simbol', dan melakukan klik dengan ripple effect.")
print("3. Mouse fisik Anda TIDAK PERNAH dibajak atau dipindahkan.")
print("4. Judul jendela TradingView diverifikasi secara tertutup (closed-loop).")
print("==================================================================")

// 1. Memeriksa apakah boringNotch aktif berjalan
let runningApps = NSWorkspace.shared.runningApplications
guard let app = runningApps.first(where: { $0.bundleIdentifier == "com.heizaaa.izanotch" || $0.localizedName == "boringNotch" }) else {
    print("❌ ERROR: Aplikasi boringNotch tidak sedang berjalan!")
    print("Jalankan aplikasi terlebih dahulu dengan: open .../boringNotch.app")
    exit(1)
}
print("✅ boringNotch aktif terdeteksi (PID: \(app.processIdentifier))")

// 2. Memeriksa judul jendela TradingView sebelum switching
func getTradingViewTitle() -> (id: Int, title: String)? {
    let wins = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
    for w in wins {
        let owner = w[kCGWindowOwnerName as String] as? String ?? ""
        let layer = w[kCGWindowLayer as String] as? Int ?? -1
        if owner == "TradingView" && layer == 0 {
            if let b = w[kCGWindowBounds as String] as? [String: Any],
               let width = b["Width"] as? CGFloat,
               let height = b["Height"] as? CGFloat,
               width >= 600 && height >= 400 {
                let id = w[kCGWindowNumber as String] as? Int ?? 0
                let title = w[kCGWindowName as String] as? String ?? ""
                return (id, title)
            }
        }
    }
    return nil
}

guard let tvInitial = getTradingViewTitle() else {
    print("❌ ERROR: TradingView tidak ditemukan di WindowServer Layer 0.")
    print("Pastikan TradingView terbuka sebelum menjalankan uji ini.")
    exit(1)
}
print("📌 Judul Jendela TradingView Sebelum Uji: '\(tvInitial.title)' (Window ID: \(tvInitial.id))")

// 3. Mengirim sinyal IPC ke boringNotch
print("\n🚀 Mengirim sinyal CUA Switch Symbol ke boringNotch...")
let center = DistributedNotificationCenter.default()
center.postNotificationName(
    NSNotification.Name("IzanotchyTestPhase2SwitchSymbol"),
    object: nil,
    userInfo: ["symbol": targetSymbol],
    deliverImmediately: true
)

print("⏳ Menunggu CuaDrive Action Cursor menyelesaikan penerbangan dan verifikasi judul (maksimal 6 detik)...")

let deadline = Date().addingTimeInterval(6.0)
var verified = false
var finalTitle = ""

while Date() < deadline {
    Thread.sleep(forTimeInterval: 0.3)
    if let current = getTradingViewTitle() {
        finalTitle = current.title
        let upper = finalTitle.uppercased()
        if upper.contains(targetSymbol) {
            verified = true
            break
        }
    }
}

// 4. Mengambil bukti tangkapan layar jendela
if let current = getTradingViewTitle() {
    let cap = Process()
    cap.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
    cap.arguments = ["-x", "-l", "\(current.id)", "/tmp/phase2_verified_window.png"]
    try? cap.run()
    cap.waitUntilExit()
}

print("\n==================================================================")
print("📊 HASIL PENGUJIAN VISUAL FASE 2")
print("==================================================================")
print("• Simbol Diminta                : \(targetSymbol)")
print("• Judul Sebelum Switching       : '\(tvInitial.title)'")
print("• Judul Sesudah Switching       : '\(finalTitle)'")
print("• Verifikasi Simbol Terbuka     : \(verified ? "✅ LOLOS (VERIFIED)" : "❌ TIMEOUT / BELUM COCOK")")
print("• File Bukti Visual             : /tmp/phase2_verified_window.png")
print("==================================================================")

if verified {
    print("🎉 SUKSES BESAR: FASE 2 BERHASIL DIVERIFIKASI SECARA CLOSED-LOOP!")
    print("Buka bukti visual dengan perintah: open /tmp/phase2_verified_window.png")
    exit(0)
} else {
    print("⚠️ Verifikasi judul belum terpenuhi dalam batas waktu. Periksa log: cat ~/Library/Logs/Izanotchy/clicky.log")
    exit(1)
}
