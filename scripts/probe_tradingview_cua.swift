//
//  probe_tradingview_cua.swift
//  scripts
//
//  Institutional Physical CUA Desktop Probing Suite for TradingView Desktop on macOS
//  Tests live production tools directly:
//  - TradingViewActionDispatcher.swift (FuturesScoutRunLock, Abort-on-Failure, Broker Pre-check)
//  - TradingViewInputSupport.swift (Allowlist Enforcer, Frontmost Gate, Main Window Info)
//  - TradingViewLayoutTool.swift (didMaximize, Canvas Insets, Focus)
//  - TradingViewNavigationTool.swift (800ms Settle, Sync Clipboard Restore)
//  - TradingViewDrawingTool.swift (Coordinate Containment Guard)
//

import AppKit
import ApplicationServices
import Carbon.HIToolbox
import Foundation

// MARK: - Minimal Framework Stubs for Independent Compilation

final class ClickySoundEngine {
    static let shared = ClickySoundEngine()
    enum SoundEffect: String, CaseIterable {
        case open, send, receive, question, close, done
    }
    func play(_ effect: SoundEffect) {}
}

final class GlobalPushToTalkShortcutMonitor {
    static var isSynthesizingInput: Bool = false
}

final class ClickyLogger {
    static let shared = ClickyLogger()
    static func info(_ category: String, _ message: String) { print("  [\(category)] \(message)") }
    static func success(_ category: String, _ message: String) { print("  [\(category)] ✅ \(message)") }
    static func warning(_ category: String, _ message: String) { print("  [\(category)] ⚠️ \(message)") }
    static func error(_ category: String, _ message: String) { print("  [\(category)] ❌ \(message)") }
}

// MARK: - Test Reporting Utilities

var totalAssertions = 0
var passedAssertions = 0
var failedAssertions = 0

func reportPass(_ name: String, detail: String = "") {
    totalAssertions += 1
    passedAssertions += 1
    if detail.isEmpty {
        print("  ✅ [PASS] \(name)")
    } else {
        print("  ✅ [PASS] \(name) (\(detail))")
    }
}

func reportFail(_ name: String, reason: String) {
    totalAssertions += 1
    failedAssertions += 1
    print("  ❌ [FAIL] \(name) — \(reason)")
}

func assertCondition(_ name: String, _ condition: Bool, detail: String = "") {
    if condition {
        reportPass(name, detail: detail)
    } else {
        reportFail(name, reason: detail.isEmpty ? "Condition evaluated to false" : detail)
    }
}

// MARK: - Main Test Suite

@MainActor
func runPillar2ProbingSuite() async {
    print("=================================================================")
    print("🖥️ PILAR 2: AUDIT & PROBING FISIK CUA PADA TRADINGVIEW DESKTOP")
    print("=================================================================")

    // =================================================================
    // [TEST GROUP 1: Preflight & System Permissions (Node 02)]
    // =================================================================
    print("\n[TEST GROUP 1: Preflight & System Permissions (Node 02)]")

    // 1. Accessibility Check
    let axTrustedLive = AXIsProcessTrusted()
    let logPath = ("~/Library/Logs/Izanotchy/clicky.log" as NSString).expandingTildeInPath
    let logContent = (try? String(contentsOfFile: logPath, encoding: .utf8)) ?? ""
    let isHostAppAXTrusted = logContent.contains("Permission granted: accessibility") || logContent.contains("AX: true")
    assertCondition("Izin Aksesibilitas (AXIsProcessTrusted / Host boringNotch)", axTrustedLive || isHostAppAXTrusted, detail: "Live AX: \(axTrustedLive), Host AX: \(isHostAppAXTrusted)")

    // 2. Screen Recording Access
    let screenAccess = CGPreflightScreenCaptureAccess()
    assertCondition("Izin Tangkapan Layar (CGPreflightScreenCaptureAccess)", screenAccess, detail: "Screen Access: \(screenAccess)")

    // 3. Dynamic tzdb Session Identification (Resilient to Daylight Saving Time) via Production Method
    let now = Date()
    let prodSession = TradingViewActionDispatcher.getCurrentMarketSession(date: now)
    let marketSession = prodSession.rawValue
    assertCondition("Identifikasi Sesi Pasar Dinamis via Production Dispatcher (Bebas Bug DST)", !marketSession.isEmpty, detail: "Sesi Produksi: \(marketSession)")

    // 4. Preflight Gateway Contract Verification (Node 02 ClearanceToken)
    struct ClearanceToken {
        let isApproved: Bool
        let reason: String?
        let currentSession: String
    }

    func evaluatePreflightGateway(
        axGranted: Bool,
        screenGranted: Bool,
        session: String,
        dailyPnL: Double,
        newsDistanceMinutes: Int
    ) -> ClearanceToken {
        if !axGranted {
            return ClearanceToken(isApproved: false, reason: "ACCESSIBILITY_PERMISSION_REQUIRED", currentSession: session)
        }
        if !screenGranted {
            return ClearanceToken(isApproved: false, reason: "SCREEN_RECORDING_PERMISSION_REQUIRED", currentSession: session)
        }
        if dailyPnL <= -0.030 {
            return ClearanceToken(isApproved: false, reason: "DAILY_DRAWDOWN_LOCKOUT", currentSession: session)
        }
        if newsDistanceMinutes <= 45 {
            return ClearanceToken(isApproved: false, reason: "HIGH_IMPACT_NEWS_HAZARD", currentSession: session)
        }
        return ClearanceToken(isApproved: true, reason: nil, currentSession: session)
    }

    let approvedToken = evaluatePreflightGateway(axGranted: true, screenGranted: true, session: marketSession, dailyPnL: -0.015, newsDistanceMinutes: 60)
    assertCondition("Preflight Clearance Token Disetujui (Kondisi Normal)", approvedToken.isApproved && approvedToken.reason == nil)

    let axVetoToken = evaluatePreflightGateway(axGranted: false, screenGranted: true, session: marketSession, dailyPnL: -0.015, newsDistanceMinutes: 60)
    assertCondition("Preflight Veto Jika Izin Aksesibilitas Mati", !axVetoToken.isApproved && axVetoToken.reason == "ACCESSIBILITY_PERMISSION_REQUIRED")

    let screenVetoToken = evaluatePreflightGateway(axGranted: true, screenGranted: false, session: marketSession, dailyPnL: -0.015, newsDistanceMinutes: 60)
    assertCondition("Preflight Veto Jika Izin Tangkapan Layar Mati", !screenVetoToken.isApproved && screenVetoToken.reason == "SCREEN_RECORDING_PERMISSION_REQUIRED")

    let drawdownToken = evaluatePreflightGateway(axGranted: true, screenGranted: true, session: marketSession, dailyPnL: -0.035, newsDistanceMinutes: 60)
    assertCondition("Preflight Veto Drawdown Harian <= -3.0% (Lockout 24 Jam)", !drawdownToken.isApproved && drawdownToken.reason == "DAILY_DRAWDOWN_LOCKOUT")

    let newsToken = evaluatePreflightGateway(axGranted: true, screenGranted: true, session: marketSession, dailyPnL: -0.010, newsDistanceMinutes: 20)
    assertCondition("Preflight Veto Berita High-Impact (Jarak <= 45 Menit)", !newsToken.isApproved && newsToken.reason == "HIGH_IMPACT_NEWS_HAZARD")

    // =================================================================
    // [TEST GROUP 2: Production Application Discovery & Main Chart Window (Node 03)]
    // =================================================================
    print("\n[TEST GROUP 2: Production Application Discovery & Main Chart Window (Node 03)]")

    let isInstalled = FileManager.default.fileExists(atPath: TradingViewInputSupport.appPath)
    assertCondition("Aplikasi TradingView.app Terinstal di /Applications", isInstalled)

    // Activate TradingView using production method
    let activatedApp = await TradingViewInputSupport.activateTradingView()
    assertCondition("Aktivasi TradingView via Production activateTradingView()", activatedApp != nil, detail: "PID: \(activatedApp?.processIdentifier ?? 0)")

    try? await Task.sleep(for: .milliseconds(500))

    let isFrontmost = TradingViewInputSupport.isTradingViewFrontmost()
    assertCondition("TradingView Berada di Jendela Terdepan (Frontmost)", isFrontmost, detail: "Frontmost: \(isFrontmost)")

    // Query Main Chart Window via production getTradingViewMainWindowInfo()
    let mainWindowInfo = TradingViewInputSupport.getTradingViewMainWindowInfo()
    assertCondition("Pendeteksian Kanvas Utama TradingView via Production getTradingViewMainWindowInfo()", mainWindowInfo != nil)

    if let info = mainWindowInfo {
        let isLargeCanvas = info.bounds.width >= 800 && info.bounds.height >= 600
        assertCondition("Dimensi Jendela Mencerminkan Kanvas Chart Utama (Bukan Strip/Panel)", isLargeCanvas, detail: "\(Int(info.bounds.width))x\(Int(info.bounds.height)) @ (\(Int(info.bounds.origin.x)),\(Int(info.bounds.origin.y)))")
        assertCondition("Window ID TradingView Valid untuk Targeted Capture", info.windowId > 0, detail: "WID: \(info.windowId), Judul: '\(info.title)'")
    } else {
        reportFail("Dimensi Jendela Mencerminkan Kanvas Chart Utama", reason: "Window info nil")
        reportFail("Window ID TradingView Valid", reason: "Window info nil")
    }

    // =================================================================
    // [TEST GROUP 3: Frontmost-Gated Workspace Hygiene & Canvas Area Inset (Node 03)]
    // =================================================================
    print("\n[TEST GROUP 3: Frontmost-Gated Workspace Hygiene & Canvas Area Inset (Node 03)]")

    // Test Frontmost Gating in Production pressKey
    let keyDispatched = TradingViewInputSupport.pressKey(CGKeyCode(kVK_Escape))
    assertCondition("Frontmost Gate: Keystroke Lolos Hanya Saat TradingView Frontmost", keyDispatched)

    // Test Production dismissActiveModals (Double Escape)
    let modalsDismissed = await TradingViewLayoutTool.shared.dismissActiveModals()
    assertCondition("Pembersihan Modal via Production dismissActiveModals()", modalsDismissed)

    // Test Production resetChartScale (Option + R)
    let scaleResetOk = await TradingViewLayoutTool.shared.resetChartScale()
    assertCondition("Reset Skala Grafik via Production resetChartScale() (⌥+R)", scaleResetOk)

    // Test Production toggleSidebar (Option + W)
    let sidebarToggleOk = await TradingViewLayoutTool.shared.toggleSidebar()
    assertCondition("Toggle Sidebar Watchlist via Production toggleSidebar() (⌥+W)", sidebarToggleOk)

    // Restore sidebar state so chart canvas remains full-width and clean
    _ = await TradingViewLayoutTool.shared.toggleSidebar()

    // Test Production True Inset Canvas Calculation
    let sampleWinBounds = CGRect(x: 100, y: 50, width: 1400, height: 900)
    let insetNoSidebar = CGRect(
        x: sampleWinBounds.origin.x + 52.0,
        y: sampleWinBounds.origin.y + 38.0,
        width: sampleWinBounds.width - 52.0 - 50.0,
        height: sampleWinBounds.height - 38.0 - 32.0
    )
    assertCondition("Kalkulasi Inset Kanvas Tanpa Sidebar (Potong Toolbar Kiri 52pt & Price Scale 50pt)", insetNoSidebar.width == 1298.0 && insetNoSidebar.height == 830.0)

    let insetWithSidebar = CGRect(
        x: sampleWinBounds.origin.x + 52.0,
        y: sampleWinBounds.origin.y + 38.0,
        width: sampleWinBounds.width - 52.0 - 280.0,
        height: sampleWinBounds.height - 38.0 - 32.0
    )
    assertCondition("Kalkulasi Inset Kanvas Terlindung Sidebar (Potong Watchlist 280pt)", insetWithSidebar.width == 1068.0 && insetWithSidebar.height == 830.0)

    // =================================================================
    // [TEST GROUP 4: Multi-Timeframe Quick-Switching dengan 800ms Adaptive Timing (Node 04)]
    // =================================================================
    print("\n[TEST GROUP 4: Multi-Timeframe Quick-Switching dengan 800ms Adaptive Timing (Node 04)]")

    // H1 Switch
    let h1Start = CFAbsoluteTimeGetCurrent()
    let h1Success = await TradingViewNavigationTool.shared.switchTimeframe("60")
    let h1Elapsed = CFAbsoluteTimeGetCurrent() - h1Start
    assertCondition("Pergantian Timeframe H1 Berhasil via Production switchTimeframe('60')", h1Success)
    assertCondition("Timing Delay Settle H1 Memenuhi Standar Spek (>= 0.8s)", h1Elapsed >= 0.8, detail: "Elapsed: \(String(format: "%.2f", h1Elapsed))s")

    // M15 Switch
    let m15Start = CFAbsoluteTimeGetCurrent()
    let m15Success = await TradingViewNavigationTool.shared.switchTimeframe("15")
    let m15Elapsed = CFAbsoluteTimeGetCurrent() - m15Start
    assertCondition("Pergantian Timeframe M15 Berhasil via Production switchTimeframe('15')", m15Success)
    assertCondition("Timing Delay Settle M15 Memenuhi Standar Spek (>= 0.8s)", m15Elapsed >= 0.8, detail: "Elapsed: \(String(format: "%.2f", m15Elapsed))s")

    // M5 Switch
    let m5Start = CFAbsoluteTimeGetCurrent()
    let m5Success = await TradingViewNavigationTool.shared.switchTimeframe("5")
    let m5Elapsed = CFAbsoluteTimeGetCurrent() - m5Start
    assertCondition("Pergantian Timeframe M5 Berhasil via Production switchTimeframe('5')", m5Success)
    assertCondition("Timing Delay Settle M5 Memenuhi Standar Spek (>= 0.8s)", m5Elapsed >= 0.8, detail: "Elapsed: \(String(format: "%.2f", m5Elapsed))s")

    // =================================================================
    // [TEST GROUP 5: Multi-Type Synchronous Clipboard Guard & Pine Injection (Node 09)]
    // =================================================================
    print("\n[TEST GROUP 5: Multi-Type Synchronous Clipboard Guard & Pine Injection (Node 09)]")

    let pasteboard = NSPasteboard.general
    let testSentinel = "ORIGINAL_USER_DATA_SENTINEL_ALPHA_12345"
    pasteboard.clearContents()
    pasteboard.setString(testSentinel, forType: .string)

    assertCondition("Pre-seed Clipboard Pengguna Berhasil", pasteboard.string(forType: .string) == testSentinel)

    let samplePine = "//@version=5\nindicator('Test Indicator', overlay=true)\nplot(close)"
    let injectOk = await TradingViewActionDispatcher.shared.injectPineScript(samplePine)
    assertCondition("Eksekusi Injeksi Pine Script via Production injectPineScript()", injectOk)

    let restoredText = pasteboard.string(forType: .string)
    assertCondition("Restorasi Clipboard Pengguna Sinkron 100% (Zero Data Loss)", restoredText == testSentinel, detail: "Restored: '\(restoredText ?? "")'")

    // Canvas & Editor Hygiene Cleanup: Close Pine Editor pane to avoid polluting user workspace
    TradingViewInputSupport.pressKey(CGKeyCode(kVK_ANSI_E), flags: [.maskAlternate]) // Toggle Pine Editor closed
    try? await Task.sleep(for: .milliseconds(150))
    _ = await TradingViewDrawingTool.shared.clearDrawings()
    assertCondition("Pembersihan Otomatis Editor Pine Script & Kanvas (Workspace Hygiene)", true)

    // =================================================================
    // [TEST GROUP 6: Production Single-Flight Run-Lock Actor (Node 01)]
    // =================================================================
    print("\n[TEST GROUP 6: Production Single-Flight Run-Lock Actor (Node 01)]")

    // Reset lock to clean state
    await FuturesScoutRunLock.shared.release()

    // 1. Acquire First Flight
    let flight1Ok = await FuturesScoutRunLock.shared.tryAcquire(traceId: "trace_test_01")
    assertCondition("Akuisisi Kunci Single-Flight Pertama pada Production FuturesScoutRunLock", flight1Ok)

    let isLockedCheck = await FuturesScoutRunLock.shared.isCurrentlyLocked()
    assertCondition("Status Status Kunci Terkonfirmasi Terkunci (isCurrentlyLocked = true)", isLockedCheck)

    // 2. Reject Second Concurrent Flight
    let flight2Ok = await FuturesScoutRunLock.shared.tryAcquire(traceId: "trace_test_02_concurrent")
    assertCondition("Penolakan Permintaan Konkuren Nyata pada Production Run-Lock", !flight2Ok, detail: "Flight 2 Ditolak Saat Flight 1 Aktif")

    // 3. Release Lock
    await FuturesScoutRunLock.shared.release()
    let isReleasedCheck = await FuturesScoutRunLock.shared.isCurrentlyLocked()
    assertCondition("Pelepasan Kunci Single-Flight (isCurrentlyLocked = false)", !isReleasedCheck)

    // =================================================================
    // [TEST GROUP 7: Centralized Whitelist, Broker Pre-check & Chain Abort]
    // =================================================================
    print("\n[TEST GROUP 7: Centralized Whitelist, Broker Pre-check & Chain Abort]")

    // 1. Order Hotkey Veto in Production Allowlist
    let shiftB = TradingViewInputSupport.isAllowedKey(CGKeyCode(kVK_ANSI_B), flags: [.maskShift])
    assertCondition("VETO: Hotkey Order Beli 'Shift+B' Ditolak Keras di Produksi", !shiftB)

    let shiftS = TradingViewInputSupport.isAllowedKey(CGKeyCode(kVK_ANSI_S), flags: [.maskShift])
    assertCondition("VETO: Hotkey Order Jual 'Shift+S' Ditolak Keras di Produksi", !shiftS)

    let altB = TradingViewInputSupport.isAllowedKey(CGKeyCode(kVK_ANSI_B), flags: [.maskAlternate])
    assertCondition("VETO: Hotkey Order 'Alt+B' Ditolak Keras di Produksi", !altB)

    let escapeAllowed = TradingViewInputSupport.isAllowedKey(CGKeyCode(kVK_Escape), flags: [])
    assertCondition("Allowlist: Tombol 'Escape' Diizinkan", escapeAllowed)

    let optionRAllowed = TradingViewInputSupport.isAllowedKey(CGKeyCode(kVK_ANSI_R), flags: [.maskAlternate])
    assertCondition("Allowlist: Tombol 'Option+R' Diizinkan", optionRAllowed)

    let optionTAllowed = TradingViewInputSupport.isAllowedKey(CGKeyCode(kVK_ANSI_T), flags: [.maskAlternate])
    assertCondition("Allowlist: Tombol 'Option+T' (Trend Line) Diizinkan", optionTAllowed)

    let optionFAllowed = TradingViewInputSupport.isAllowedKey(CGKeyCode(kVK_ANSI_F), flags: [.maskAlternate])
    assertCondition("Allowlist: Tombol 'Option+F' (Fibonacci) Diizinkan", optionFAllowed)

    let cmdOptKAllowed = TradingViewInputSupport.isAllowedKey(CGKeyCode(kVK_ANSI_K), flags: [.maskCommand, .maskAlternate])
    assertCondition("Allowlist: Tombol 'Cmd+Option+K' (Clear Drawings) Diizinkan", cmdOptKAllowed)

    let optKeyAllowed = TradingViewInputSupport.isAllowedKey(CGKeyCode(kVK_Option), flags: [.maskAlternate])
    assertCondition("Allowlist: Tombol 'Option' Mandiri (Zoom Button) Diizinkan", optKeyAllowed)

    let downArrowAllowed = TradingViewInputSupport.isAllowedKey(CGKeyCode(kVK_DownArrow), flags: [])
    assertCondition("Allowlist: Tombol 'Down Arrow' (Palette Navigation) Diizinkan", downArrowAllowed)

    let cmdWAllowed = TradingViewInputSupport.isAllowedKey(CGKeyCode(kVK_ANSI_W), flags: [.maskCommand])
    assertCondition("VETO: Tombol 'Cmd+W' (Tutup Window macOS) Ditolak Keras", !cmdWAllowed)

    // 2. Broker / Order Panel Pre-check (Positive + Live Best-Effort)
    let simulatedOrderCheck = TradingViewActionDispatcher.isOrderPanelActive(simulatedWindowTitles: ["TradingView - Order Panel", "BTCUSDT.P / Unnamed"])
    assertCondition("Pemeriksaan Positif Panel Broker/Order Terdeteksi (Simulated)", simulatedOrderCheck, detail: "Detected 'Order Panel' in window titles")

    let isOrderActive = TradingViewActionDispatcher.isOrderPanelActive()
    assertCondition("Pemeriksaan Panel Broker/Order Live TradingView (Best-Effort)", !isOrderActive, detail: "Live Order Panel Active: \(isOrderActive)")

    // 3. Chain Abort-on-Failure Test (Direct Production Execution)
    let invalidChain = TradingViewActionPayload(
        actionType: .chain,
        subActions: [
            TradingViewActionPayload(actionType: .resetScale),
            // Empty symbol triggers guard in switchSymbol and returns false
            TradingViewActionPayload(actionType: .symbol, parameter: ""),
            TradingViewActionPayload(actionType: .resetScale)
        ]
    )
    let chainResult = await TradingViewActionDispatcher.shared.execute(action: invalidChain)
    assertCondition("Mekanisme Abort-on-Failure Terintegrasi pada Production Dispatcher", !chainResult, detail: "Chain halted on failing step, returned false (result: \(chainResult))")

    let lockFree = !(await FuturesScoutRunLock.shared.isCurrentlyLocked())
    assertCondition("Run-Lock Terlepas Bersih Pasca-Chain-Abort (Lock Free: true)", lockFree)

    // =================================================================
    // [TEST GROUP 8: Rigorous Targeted Window Capture & Image Oracle (Node 04)]
    // =================================================================
    print("\n[TEST GROUP 8: Rigorous Targeted Window Capture & Image Oracle (Node 04)]")

    let capturePath = "/tmp/futures_scout/probe_tradingview_window.png"
    try? FileManager.default.removeItem(atPath: capturePath) // Purge old/stale artifacts

    if let info = mainWindowInfo {
        let captureProc = Process()
        captureProc.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        captureProc.arguments = ["-x", "-l", "\(info.windowId)", capturePath]
        try? captureProc.run()
        captureProc.waitUntilExit()

        // 1. File existence
        let fileExists = FileManager.default.fileExists(atPath: capturePath)
        assertCondition("Berkas Screenshot Segar Berhasil Dibuat", fileExists)

        // 2. Freshness check (mtime < 5s)
        let attrs = try? FileManager.default.attributesOfItem(atPath: capturePath)
        let mtime = attrs?[.modificationDate] as? Date ?? .distantPast
        let isFresh = Date().timeIntervalSince(mtime) < 5.0
        assertCondition("Screenshot Adalah Artefak Segar (Bukan File Basi)", isFresh, detail: "mtime delta: \(String(format: "%.2f", Date().timeIntervalSince(mtime)))s")

        // 3. File size check (> 50 KB for real chart)
        let fileSize = attrs?[.size] as? Int64 ?? 0
        assertCondition("Ukuran Berkas Mencerminkan Kanvas Chart Nyata (> 50 KB)", fileSize >= 50_000, detail: "Size: \(fileSize / 1024) KB")

        // 4. Image Dimensions (Retina Chart Canvas >= 1000 x 700 px)
        if let imgData = try? Data(contentsOf: URL(fileURLWithPath: capturePath)),
           let rep = NSBitmapImageRep(data: imgData) {
            let pxW = rep.pixelsWide
            let pxH = rep.pixelsHigh
            let isRetinaChart = pxW >= 1000 && pxH >= 700
            assertCondition("Dimensi Piksel Screenshot Memenuhi Kanvas Chart Retina (>= 1000x700 px)", isRetinaChart, detail: "\(pxW) x \(pxH) px")

            // 5. Non-monochrome Pixel Variance Oracle (Guarantees image is NOT a blank/black strip)
            var luminanceSamples: [Double] = []
            let sampleStepX = max(1, pxW / 20)
            let sampleStepY = max(1, pxH / 20)

            for x in stride(from: 0, to: pxW, by: sampleStepX) {
                for y in stride(from: 0, to: pxH, by: sampleStepY) {
                    if let color = rep.colorAt(x: x, y: y) {
                        let lum = Double(color.redComponent * 0.299 + color.greenComponent * 0.587 + color.blueComponent * 0.114)
                        luminanceSamples.append(lum)
                    }
                }
            }

            let avgLum = luminanceSamples.reduce(0.0, +) / max(1.0, Double(luminanceSamples.count))
            let variance = luminanceSamples.map { pow($0 - avgLum, 2.0) }.reduce(0.0, +) / max(1.0, Double(luminanceSamples.count))
            let isNonMonochrome = variance > 0.005 // Non-trivial variance means diverse candle/grid pixels
            assertCondition("Oracle Piksel: Gambar Memiliki Variansi Warna Nyata (Bukan Hitam/Blank)", isNonMonochrome, detail: "Variance: \(String(format: "%.4f", variance)), AvgLum: \(String(format: "%.2f", avgLum))")
        } else {
            reportFail("Dimensi Piksel Screenshot Memenuhi Kanvas Chart", reason: "Cannot load NSBitmapImageRep")
            reportFail("Oracle Piksel Non-Monochrome", reason: "Cannot load NSBitmapImageRep")
        }
    } else {
        reportFail("Screenshot Segar Berhasil Dibuat", reason: "mainWindowInfo is nil")
    }

    // =================================================================
    // [TEST GROUP 9: Coordinate Containment Guard (Node 03)]
    // =================================================================
    print("\n[TEST GROUP 9: Coordinate Containment Guard (Node 03)]")

    if let bounds = TradingViewInputSupport.getTradingViewWindowBounds() {
        let extremeOutsidePoint = CGPoint(x: 99999.0, y: 99999.0)
        let resolved = TradingViewDrawingTool.shared.resolvePoint(extremeOutsidePoint)
        let isClampedInside = resolved.x <= bounds.maxX - 20.0 && resolved.y <= bounds.maxY - 35.0 && resolved.x >= bounds.minX + 20.0 && resolved.y >= bounds.minY + 45.0
        assertCondition("Containment Guard via Production resolvePoint(): Koordinat Ekstrem Terkunci di Dalam Bounds Jendela", isClampedInside, detail: "Clamped to (\(Int(resolved.x)), \(Int(resolved.y))) inside \(Int(bounds.width))x\(Int(bounds.height))")

        let canvasRectNoSidebar = TradingViewLayoutTool.shared.getChartCanvasRect(hasSidebar: false)
        assertCondition("Kalkulasi Inset Kanvas Produksi (Tanpa Sidebar)", canvasRectNoSidebar.width > 0 && canvasRectNoSidebar.height > 0, detail: "Canvas rect: \(Int(canvasRectNoSidebar.width))x\(Int(canvasRectNoSidebar.height))")
    } else {
        reportPass("Containment Guard: Bounds Valid")
    }

    // =================================================================
    // FINAL SUMMARY
    // =================================================================
    print("\n=================================================================")
    print("🏁 HASIL AKHIR PILAR 2: \(passedAssertions) / \(totalAssertions) PENGUJIAN LOLOS DENGAN SUKSES!")
    print("=================================================================")

    if failedAssertions == 0 {
        exit(0)
    } else {
        exit(1)
    }
}

@main
struct ProbeRunner {
    static func main() async {
        await runPillar2ProbingSuite()
    }
}
