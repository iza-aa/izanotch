//
//  ClickyDeterministicPipeline+ExecutionChains.swift
//  izaNotch (Izanotchy)
//
//  Lapis 3: Execution Chains for ClickyDeterministicPipeline.
//

import AppKit
import CoreGraphics
import Defaults
import Foundation

extension ClickyDeterministicPipeline {
    // MARK: - Lapis 3: Rantai Deterministik Master Dispatcher

    func processCommand(
        transcript: String,
        screenCaptures: [CompanionScreenCapture],
        workSurface: ActiveWorkSurface?
    ) async {
        let clean = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }

        // 0. Fast-Path: On-Demand Chart Analysis (Strict atomic priority, NEVER send to chain decomposition!)
        let category = await Self.classifyCommandIntent(clean)
        if case .aksi(let actionType, let target) = category, actionType == "analisa" || actionType == "analisis" || actionType == "analisa_market" {
            ClickyLogger.info("[PIPELINE]", "Fast-path: Executing On-Demand Chart Analysis for \(target)")
            await executeAksiChain(
                actionType: actionType,
                target: target,
                rawCommand: clean,
                isChainedStep: false,
                screenCaptures: screenCaptures,
                workSurface: workSurface
            )
            return
        }

        // Multi-Step Chained Command Detection (Only for non-slash general commands)
        if !clean.hasPrefix("/") && !clean.hasPrefix("!") {
            let steps = await Self.splitChainedCommand(transcript: clean)
            if steps.count > 1 {
                ClickyLogger.info("[PIPELINE]", "Executing multi-step chained command with \(steps.count) steps: \(steps)")
                await executeChainedSteps(steps: steps, screenCaptures: screenCaptures, initialWorkSurface: workSurface)
                return
            }
        }

        ClickyLogger.info("[PIPELINE]", "Command classified: \(category)")

        switch category {
        case .tanya(let query):
            await executeTanyaChain(query: query, screenCaptures: screenCaptures, workSurface: workSurface)

        case .tunjuk(let target):
            await executeTunjukChain(target: target, screenCaptures: screenCaptures, workSurface: workSurface)

        case .aksi(let actionType, let target):
            await executeAksiChain(
                actionType: actionType,
                target: target,
                rawCommand: clean,
                isChainedStep: false,
                screenCaptures: screenCaptures,
                workSurface: workSurface
            )
        }
    }

    private func executeChainedSteps(
        steps: [String],
        screenCaptures: [CompanionScreenCapture],
        initialWorkSurface: ActiveWorkSurface?
    ) async {
        CompanionManager.shared.setIntermediateStatusText("Menjalankan \(steps.count) langkah perintah...")
        var currentWs = initialWorkSurface

        for (index, step) in steps.enumerated() {
            let stepNum = index + 1
            ClickyLogger.info("[CHAIN]", "Executing Step \(stepNum)/\(steps.count): '\(step)'")
            CompanionManager.shared.setIntermediateStatusText("Langkah \(stepNum)/\(steps.count): \(step)...")

            let category = await Self.classifyCommandIntent(step)
            switch category {
            case .tanya(let query):
                await executeTanyaChain(query: query, screenCaptures: screenCaptures, workSurface: currentWs)

            case .tunjuk(let target):
                await executeTunjukChain(target: target, screenCaptures: screenCaptures, workSurface: currentWs)

            case .aksi(let actionType, let target):
                await executeAksiChain(
                    actionType: actionType,
                    target: target,
                    rawCommand: step,
                    isChainedStep: true,
                    screenCaptures: screenCaptures,
                    workSurface: currentWs
                )
            }

            // Sync delay antar-langkah agar sistem operasi dan antarmuka jendela beradaptasi
            if index < steps.count - 1 {
                let delayMs: UInt64 = {
                    let lower = step.lowercased()
                    if lower.contains("buka") || lower.contains("open") || lower.contains("launch") {
                        return 400
                    } else if lower.contains("buat") || lower.contains("klik") || lower.contains("tekan") {
                        return 300
                    }
                    return 200
                }()
                try? await Task.sleep(for: .milliseconds(delayMs))

                // Refresh active work surface untuk langkah berikutnya
                currentWs = ActiveWorkSurfaceManager.getActiveWorkSurface()
            }
        }

        ClickySoundEngine.shared.play(.done)
        await CompanionManager.shared.speakAndReportText("Selesai, semua \(steps.count) langkah perintah berhasil dijalankan.")
    }

    // MARK: - Chain 1: TANYA (Direct Chat / Knowledge)

    private func executeTanyaChain(
        query: String,
        screenCaptures: [CompanionScreenCapture],
        workSurface: ActiveWorkSurface?
    ) async {
        CompanionManager.shared.setIntermediateStatusText("Berpikir...")

        let siriPlanner = CompanionManager.shared.isSiriAI
        let systemPrompt = CompanionManager.buildCompanionVoiceResponseSystemPrompt(
            workSurface: workSurface,
            buddy: CompanionManager.shared.activeBuddy,
            isPreApproved: CompanionManager.shared.isTaskSessionPreApproved,
            isSiriAIPlannerPath: siriPlanner
        )

        let messages: [[String: Any]] = [
            ["role": "user", "content": query]
        ]

        var accumulatedText = ""
        do {
            if siriPlanner {
                _ = try await SiriAIEngine.shared.analyzeMessagesWithToolsStreaming(
                    messages: messages,
                    systemPrompt: systemPrompt,
                    tools: [], // 0 tools, direct conversational response
                    maxTokens: 512,
                    onTextChunk: { chunk in
                        Task { @MainActor in
                            accumulatedText += chunk
                            CompanionManager.shared.showStreamingChunk(chunk, screenCaptures: screenCaptures)
                        }
                    }
                )
            } else {
                _ = try await CompanionManager.shared.claudeAPI.analyzeMessagesWithToolsStreaming(
                    messages: messages,
                    systemPrompt: systemPrompt,
                    tools: [], // 0 tools, fast knowledge response
                    maxTokens: 512,
                    onTextChunk: { chunk in
                        Task { @MainActor in
                            accumulatedText += chunk
                            CompanionManager.shared.showStreamingChunk(chunk, screenCaptures: screenCaptures)
                        }
                    }
                )
            }

            let report = accumulatedText.trimmingCharacters(in: .whitespacesAndNewlines)
            if !report.isEmpty {
                await CompanionManager.shared.speakAndReportText(report)
            }
        } catch {
            ClickyLogger.error("[PIPELINE]", "TANYA chain failed: \(error.localizedDescription)")
            await CompanionManager.shared.speakAndReportText("Maaf, terjadi kendala saat memproses jawaban: \(error.localizedDescription)")
        }
    }

    // MARK: - Chain 2: TUNJUK (Read-Only Grounding & Pointing)

    private func executeTunjukChain(
        target: String,
        screenCaptures: [CompanionScreenCapture],
        workSurface: ActiveWorkSurface?
    ) async {
        let uiClueWords = [
            "button", "tombol", "tab", "menu", "dropdown", "icon", "ikon",
            "link", "checkbox", "expand", "collapse", "input", "kolom", "field"
        ]
        let lowerTarget = target.lowercased()
        let hasUIClue = uiClueWords.contains { lowerTarget.contains($0) }
        let resolvedApp = !hasUIClue ? InstalledApplicationsResolver.shared.resolveApplication(query: target) : nil
        let effectiveTarget = resolvedApp?.displayName ?? target

        // Step 1: Update UI status
        CompanionManager.shared.setIntermediateStatusText("Mencari \(effectiveTarget)...")

        // Step 2: ground_ax fast-path (~50ms)
        var point: CGPoint? = groundAX(target: effectiveTarget, workSurface: workSurface)
        var visualServerError: String? = nil

        // Step 3: ground_visual fallback
        if point == nil {
            if let capture = screenCaptures.first(where: { $0.isCursorScreen }) ?? screenCaptures.first {
                CompanionManager.shared.setIntermediateStatusText("Menganalisis tampilan layar untuk '\(effectiveTarget)'...")
                do {
                    point = try await groundVisual(target: effectiveTarget, capture: capture)
                } catch {
                    visualServerError = error.localizedDescription
                    ClickyLogger.warning("[PIPELINE]", "ground_visual threw: \(error.localizedDescription)")
                }
            }
        }

        // Step 4: Gate In-Screen & Flight
        if let pt = point, isInScreenBounds(pt) {
            flyTo(point: pt, label: effectiveTarget)
            let report = "Itu dia, \(effectiveTarget) di layar!"
            await CompanionManager.shared.speakAndReportText(report)
        } else if let pt = point {
            ClickyLogger.warning("[PIPELINE]", "Target found but rejected by in-screen bounds: (\(Int(pt.x)), \(Int(pt.y)))")
            await CompanionManager.shared.speakAndReportText("Maaf, posisi \(effectiveTarget) berada di luar batas layar yang terlihat.")
        } else if let _ = visualServerError {
            await CompanionManager.shared.speakAndReportText("Maaf, server visual sedang sibuk saat ini. Silakan coba sesaat lagi.")
        } else {
            await CompanionManager.shared.speakAndReportText("Maaf, saya tidak dapat menemukan '\(effectiveTarget)' di layar saat ini.")
        }
    }

    // MARK: - Chain 3: AKSI (Protected Physical Execution with Consent & Verification)

    private func executeAksiChain(
        actionType: String,
        target: String,
        rawCommand: String = "",
        isChainedStep: Bool = false,
        screenCaptures: [CompanionScreenCapture],
        workSurface: ActiveWorkSurface?
    ) async {
        // Case D: Aksi Ketik Teks (Keyboard Physical Typing via Siri AI Intent Extraction)
        // e.g. "ketik belanja bulanan di notes", "tolong ketik btc/usdt di search", "ketik halo apa kabar"
        if actionType == "ketik" || actionType == "type" {
            await executeKetikChain(
                rawCommand: rawCommand.isEmpty ? target : rawCommand,
                fallbackTarget: target,
                isChainedStep: isChainedStep,
                screenCaptures: screenCaptures,
                workSurface: workSurface
            )
            return
        }

        // Case E: On-Demand Chart Analysis (Option B Canon)
        // e.g. "analisa BTCUSDT", "/analisa ETH", "analisa chart SOL"
        if actionType == "analisa" || actionType == "analisis" {
            CompanionManager.shared.setIntermediateStatusText("Menganalisis chart \(target)...")
            await FuturesScoutChartAnalyst.shared.analyzeAndReport(symbol: target)
            return
        }

        // Case E2: Multi-Market Radar Scan (Reviewer Canon)
        // e.g. "/analisa market", "analisa pasar", "/analisa market btc eth sol"
        if actionType == "analisa_market" {
            let customMarkets = target.isEmpty ? nil : target.split(separator: " ").map { String($0) }
            CompanionManager.shared.setIntermediateStatusText("Memindai pasar kripto (Market Radar)...")
            await FuturesScoutChartAnalyst.shared.analyzeMarketAndReport(customMarkets: customMarkets)
            return
        }

        let isAppLaunchVerb = actionType == "buka" || actionType == "open" || actionType == "launch" || actionType == "jalankan"
        let isClose = actionType == "tutup" || actionType == "close" || actionType == "quit"

        // Lapis 3: Deteksi Kata Kunci Komponen UI
        let uiClueWords = [
            "button", "tombol", "tab", "menu", "dropdown", "icon", "ikon",
            "link", "checkbox", "expand", "collapse", "input", "kolom", "field",
            "radio", "slider", "toggle", "switch", "popup", "dialog"
        ]
        let lowerTarget = target.lowercased()
        let hasUIClue = uiClueWords.contains { clue in
            lowerTarget.contains(clue)
        }

        // Lapis 2: Verifikasi Bundle Aplikasi Terpasang
        // HANYA dianggap app launch jika kata kerjanya adalah buka/launch, BUKAN elemen UI, dan terdaftar di disk.
        let installedApp = (isAppLaunchVerb && !hasUIClue) ? InstalledApplicationsResolver.shared.resolveApplication(query: target) : nil
        let isAppLaunchIntent = (installedApp != nil)

        // Case A: Murni Membuka Aplikasi Mac Terpasang (e.g. "buka trading view", "buka safari")
        if isAppLaunchIntent, let app = installedApp {
            CompanionManager.shared.setIntermediateStatusText("Mencari '\(app.displayName)'...")

            // Cek cepat apakah ada di Dock atau di layar (fast-path AX ~20ms)
            let point = groundAX(target: app.displayName, workSurface: workSurface)

            if let pt = point, isInScreenBounds(pt) {
                // Ada di Dock / Layar! Kursor CUA meluncur dan klik Dock icon
                CompanionManager.shared.setIntermediateStatusText("Mempersiapkan perintah '\(app.displayName)'...")

                let isFullAccess = Defaults[.alwaysAllowComputerUse] || CompanionManager.shared.isTaskSessionPreApproved
                if !isFullAccess {
                    CompanionManager.shared.setIntermediateStatusText("Menunggu izin untuk '\(app.displayName)'...")
                    let approved = await mintaConsent(actionType: "buka", target: app.displayName, point: pt)
                    guard approved else {
                        await CompanionManager.shared.speakAndReportText("Perintah untuk '\(app.displayName)' dibatalkan.")
                        return
                    }
                }

                CompanionManager.shared.setIntermediateStatusText("Menjalankan perintah untuk '\(app.displayName)'...")
                await klikFisik(point: pt, actionType: "buka", target: app.displayName, workSurface: workSurface)

                let isVerified = await verifikasiVisual(actionType: "buka", target: app.displayName, workSurface: workSurface)
                if isVerified {
                    if !isChainedStep {
                        ClickySoundEngine.shared.play(.done)
                        await CompanionManager.shared.speakAndReportText("Selesai, membuka \(app.displayName).")
                    }
                } else {
                    if !isChainedStep {
                        await CompanionManager.shared.speakAndReportText("Perintah untuk '\(app.displayName)' telah dikirim.")
                    }
                }
            } else {
                // TIDAK ADA DI DOCK: Fast-path direct launch via NSWorkspace (< 0.1 detik, TANPA groundVisual!)
                CompanionManager.shared.setIntermediateStatusText("Membuka \(app.displayName)...")
                ClickyLogger.info("[PIPELINE]", "Fast-path direct launching app: \(app.displayName) at \(app.bundleURL.path)")

                let config = NSWorkspace.OpenConfiguration()
                config.activates = true
                do {
                    _ = try await NSWorkspace.shared.openApplication(at: app.bundleURL, configuration: config)
                    if !isChainedStep {
                        ClickySoundEngine.shared.play(.done)
                        await CompanionManager.shared.speakAndReportText("Selesai, membuka \(app.displayName).")
                    }
                } catch {
                    ClickyLogger.error("[PIPELINE]", "Failed to launch application \(app.displayName): \(error.localizedDescription)")
                    await CompanionManager.shared.speakAndReportText("Gagal membuka \(app.displayName): \(error.localizedDescription)")
                }
            }
            return
        }

        // Case B: Menutup Aplikasi atau Window (e.g. "tutup trading view", "close safari")
        if isClose {
            CompanionManager.shared.setIntermediateStatusText("Mencari '\(target)' untuk ditutup...")

            // Grounding ke tombol close (AX -> Visual)
            var point = groundAX(target: target, workSurface: workSurface)
            if point == nil {
                if let capture = screenCaptures.first(where: { $0.isCursorScreen }) ?? screenCaptures.first {
                    point = try? await groundVisual(target: target, capture: capture)
                }
            }

            if let pt = point, isInScreenBounds(pt) {
                // Ada di layar, klik via CUA
                let isFullAccess = Defaults[.alwaysAllowComputerUse] || CompanionManager.shared.isTaskSessionPreApproved
                if !isFullAccess {
                    let approved = await mintaConsent(actionType: "tutup", target: target, point: pt)
                    guard approved else {
                        await CompanionManager.shared.speakAndReportText("Aksi tutup dibatalkan sesuai pilihan Anda.")
                        return
                    }
                }
                await klikFisik(point: pt, actionType: "tutup", target: target, workSurface: workSurface)
                let isVerified = await verifikasiVisual(actionType: "tutup", target: target, workSurface: workSurface)
                if isVerified {
                    if !isChainedStep {
                        ClickySoundEngine.shared.play(.done)
                        await CompanionManager.shared.speakAndReportText("Selesai, menutup '\(target)'.")
                    }
                } else {
                    ComputerUsePhysicalExecutor.shared.executeNamedKeyCombo("cmd+w")
                    if !isChainedStep {
                        await CompanionManager.shared.speakAndReportText("Aksi tutup telah dikirim.")
                    }
                }
            } else {
                // Tidak ada di layar: Cek running application via NSWorkspace
                let cleanTarget = target.lowercased().filter { $0.isLetter || $0.isNumber }
                let matchedRunning = NSWorkspace.shared.runningApplications.first(where: { running in
                    guard let name = running.localizedName?.lowercased() else { return false }
                    let cleanName = name.filter { $0.isLetter || $0.isNumber }
                    return cleanName == cleanTarget || cleanName.contains(cleanTarget) || cleanTarget.contains(cleanName)
                })

                if let runningApp = matchedRunning {
                    runningApp.terminate()
                    if !isChainedStep {
                        ClickySoundEngine.shared.play(.done)
                        await CompanionManager.shared.speakAndReportText("Selesai, menutup \(runningApp.localizedName ?? target).")
                    }
                } else {
                    if !isChainedStep {
                        await CompanionManager.shared.speakAndReportText("Aplikasi '\(target)' tidak sedang berjalan.")
                    }
                }
            }
            return
        }

        // Case C: Lapis 1 & 3: Interaksi Elemen Layar (Button, Tombol, Tab, Menu, Dropdown, dll.)
        // e.g. "tekan button expand", "klik tombol submit", "buka tab riwayat", "pencet close", "buat notes baru"
        CompanionManager.shared.setIntermediateStatusText("Mencari target '\(target)'...")

        // Jika perintah adalah buat/tambah sesuatu pada aplikasi tertentu (misal: "buat notes baru"):
        // Pastikan aplikasi yang bersangkutan diangkat ke depan jika sedang berjalan di latar belakang
        var activeWs = workSurface
        if actionType == "buat" || actionType == "tambah" {
            let runningApps = NSWorkspace.shared.runningApplications
            for app in runningApps where app.activationPolicy == .regular {
                if let name = app.localizedName?.lowercased(), !name.isEmpty, target.lowercased().contains(name) {
                    if !app.isActive {
                        app.activate(options: [.activateIgnoringOtherApps])
                        try? await Task.sleep(for: .milliseconds(150))
                        activeWs = ActiveWorkSurfaceManager.getActiveWorkSurface(queryHint: target)
                    }
                    break
                }
            }
        }

        // Step 1: Grounding ke layar (AX -> Visual)
        var point: CGPoint? = groundAX(target: target, workSurface: activeWs)
        var visualServerError: String? = nil
        if point == nil {
            if let capture = screenCaptures.first(where: { $0.isCursorScreen }) ?? screenCaptures.first {
                CompanionManager.shared.setIntermediateStatusText("Menganalisis tampilan untuk '\(target)'...")
                do {
                    point = try await groundVisual(target: target, capture: capture)
                } catch {
                    visualServerError = error.localizedDescription
                    ClickyLogger.warning("[PIPELINE]", "ground_visual error during action: \(error.localizedDescription)")
                }
            }
        }

        // Step 2: Gate Found & In-Screen
        guard let pt = point, isInScreenBounds(pt) else {
            if isAppLaunchVerb && !hasUIClue {
                // Perintah menggunakan kata kerja "buka" dan bukan elemen UI, tapi tidak terpasang di Mac & tidak ada di layar
                await CompanionManager.shared.speakAndReportText("Maaf, aplikasi '\(target)' tidak ditemukan di Mac Anda.")
            } else if let _ = visualServerError {
                await CompanionManager.shared.speakAndReportText("Tidak dapat memproses permintaan, server visual sedang sibuk saat ini. Silakan coba lagi sebentar.")
            } else {
                await CompanionManager.shared.speakAndReportText("Objek '\(target)' tidak terlihat di layar.")
            }
            return
        }

        // Step 3: Gate Consent
        CompanionManager.shared.setIntermediateStatusText("Mempersiapkan perintah '\(target)'...")
        let isFullAccess = Defaults[.alwaysAllowComputerUse] || CompanionManager.shared.isTaskSessionPreApproved
        if !isFullAccess {
            CompanionManager.shared.setIntermediateStatusText("Menunggu izin untuk '\(target)'...")
            let approved = await mintaConsent(actionType: actionType, target: target, point: pt)
            guard approved else {
                await CompanionManager.shared.speakAndReportText("Perintah untuk '\(target)' dibatalkan.")
                return
            }
        }

        // Step 4: Eksekusi Fisik via Panah Agent (Kursor CUA meluncur dan klik elemen fisik di layar)
        CompanionManager.shared.setIntermediateStatusText("Menjalankan perintah untuk '\(target)'...")
        await klikFisik(point: pt, actionType: actionType, target: target, workSurface: workSurface)

        // Step 5: Verifikasi Visual Selektif
        let isVerified = await verifikasiVisual(actionType: actionType, target: target, workSurface: workSurface)
        if isVerified {
            if !isChainedStep {
                ClickySoundEngine.shared.play(.done)
                await CompanionManager.shared.speakAndReportText("Selesai, perintah untuk '\(target)' berhasil dijalankan.")
            }
        } else {
            if !isChainedStep {
                await CompanionManager.shared.speakAndReportText("Perintah untuk '\(target)' telah dikirim.")
            }
        }
    }

    // MARK: - Chain 4: KETIK (Keyboard Physical Typing via Siri AI Intent Extraction)

    private func executeKetikChain(
        rawCommand: String,
        fallbackTarget: String,
        isChainedStep: Bool = false,
        screenCaptures: [CompanionScreenCapture],
        workSurface: ActiveWorkSurface?
    ) async {
        CompanionManager.shared.setIntermediateStatusText("Memproses teks untuk diketik...")

        // 1. Ekstraksi semantik via Siri AI (Apple Foundation Models on-device NPU)
        let intent = await SiriAIEngine.shared.parseTypingIntent(command: rawCommand)
        let textToType = intent.textToType.isEmpty ? fallbackTarget : intent.textToType
        let appName = intent.appName
        let targetField = intent.targetField

        ClickyLogger.info("[PIPELINE]", "Ketik intent: app='\(appName ?? "none")', field='\(targetField ?? "none")', text='\(textToType)'")

        var activeWs = workSurface

        // 2. Aktivasi aplikasi target ke depan (Auto-Activate Opsi A)
        if let app = appName, !app.isEmpty {
            let runningApps = NSWorkspace.shared.runningApplications
            var foundRunning = false
            for running in runningApps where running.activationPolicy == .regular {
                if let name = running.localizedName?.lowercased(), !name.isEmpty,
                   name.contains(app.lowercased()) || app.lowercased().contains(name) {
                    if !running.isActive {
                        running.activate(options: [.activateIgnoringOtherApps])
                        try? await Task.sleep(for: .milliseconds(200))
                        activeWs = ActiveWorkSurfaceManager.getActiveWorkSurface(queryHint: app)
                    }
                    foundRunning = true
                    break
                }
            }
            if !foundRunning {
                // Coba buka aplikasi jika belum berjalan
                if let installed = InstalledApplicationsResolver.shared.resolveApplication(query: app) {
                    let config = NSWorkspace.OpenConfiguration()
                    config.activates = true
                    _ = try? await NSWorkspace.shared.openApplication(at: installed.bundleURL, configuration: config)
                    try? await Task.sleep(for: .milliseconds(500))
                    activeWs = ActiveWorkSurfaceManager.getActiveWorkSurface(queryHint: app)
                }
            }
        } else if let pid = activeWs?.ownerPID ?? workSurface?.ownerPID {
            // Jika nama aplikasi tidak disebutkan spesifik (misal hanya "cari disearch bar..."),
            // pastikan aplikasi yang sedang aktif di layar diangkat ke depan penuh
            if let running = NSWorkspace.shared.runningApplications.first(where: { $0.processIdentifier == pid }) {
                if !running.isActive {
                    ClickyLogger.info("[PIPELINE]", "Auto-activating frontmost surface app: \(running.localizedName ?? "") (PID: \(pid))")
                    running.activate(options: [.activateIgnoringOtherApps])
                    try? await Task.sleep(for: .milliseconds(200))
                    activeWs = ActiveWorkSurfaceManager.getActiveWorkSurface()
                }
            }
        }

        // 3. Jika ada kolom target spesifik (misal: "search", "kolom pencarian", "nomor telepon")
        let isSearchField = targetField?.lowercased().contains("search") == true ||
                            targetField?.lowercased().contains("cari") == true ||
                            rawCommand.lowercased().contains("search") ||
                            rawCommand.lowercased().contains("cari")

        let effectiveField = targetField ?? (isSearchField ? "search bar" : nil)

        if let field = effectiveField, !field.isEmpty {
            CompanionManager.shared.setIntermediateStatusText("Mencari kolom '\(field)'...")
            
            // Lapis 1: Cek AX Tree Jendela Aktif (~5ms)
            var point = groundAX(target: field, workSurface: activeWs)
            
            // Lapis 2: Fallback Visual AI Grounding (Bounding Box Center) jika aplikasi tidak punya AX
            if point == nil {
                if let capture = screenCaptures.first(where: { $0.isCursorScreen }) ?? screenCaptures.first {
                    point = try? await groundVisual(target: field, capture: capture)
                }
            }
            if let pt = point, isInScreenBounds(pt) {
                // Meluncur dan klik fisik kolom murni via CUA cursor untuk memberikan fokus keyboard
                ClickyLogger.info("[PIPELINE]", "Physical CUA cursor clicking target field: '\(field)' at AppKit (\(Int(pt.x)), \(Int(pt.y)))")
                await klikFisik(point: pt, actionType: "klik", target: field, workSurface: activeWs)
                try? await Task.sleep(for: .milliseconds(200))
            } else {
                ClickyLogger.warning("[PIPELINE]", "Target field '\(field)' could not be located on active surface.")
            }
        }

        // 4. Gate Consent (Jika bukan Full Access / Pre-approved)
        let isFullAccess = Defaults[.alwaysAllowComputerUse] || CompanionManager.shared.isTaskSessionPreApproved
        if !isFullAccess {
            CompanionManager.shared.setIntermediateStatusText("Menunggu izin untuk mengetik...")
            let displayTarget = appName ?? activeWs?.appName ?? activeWs?.windowTitle ?? "aplikasi aktif"
            let previewText = textToType.count > 30 ? String(textToType.prefix(30)) + "..." : textToType
            let approved = await mintaConsent(actionType: "ketik", target: "\(displayTarget): \"\(previewText)\"", point: NSEvent.mouseLocation)
            guard approved else {
                await CompanionManager.shared.speakAndReportText("Perintah mengetik dibatalkan.")
                return
            }
        }

        // 5. Eksekusi Pengetikan Fisik via Keyboard
        CompanionManager.shared.setIntermediateStatusText("Mengetik teks...")
        try? await Task.sleep(for: .milliseconds(150))

        // Penentuan cerdas Return/Enter:
        // Di Notes / Dokumen -> TIDAK menekan Return (agar catatan rapi tanpa baris baru tak diinginkan)
        // Di Search bar / Chat / Kolom Spesifik -> TEKAN Return
        let isDocOrNotes: Bool = {
            if let app = appName?.lowercased(), app.contains("note") || app.contains("catatan") || app.contains("text") || app.contains("word") {
                return true
            }
            if let wsApp = activeWs?.appName.lowercased(), wsApp.contains("note") || wsApp.contains("catatan") {
                return true
            }
            if let wsTitle = activeWs?.windowTitle.lowercased(), wsTitle.contains("note") || wsTitle.contains("catatan") {
                return true
            }
            return false
        }()
        let isSearchTarget = isSearchField
        let shouldAutoReturn = isSearchTarget || (!isDocOrNotes && (targetField != nil))

        ClickyLogger.info("[PIPELINE]", "Executing keyboard typing for: '\(textToType)' (shouldAutoReturn: \(shouldAutoReturn))")
        ComputerUsePhysicalExecutor.shared.executeTypeText(textToType, autoSendReturn: shouldAutoReturn)

        // 6. Selesai
        if !isChainedStep {
            ClickySoundEngine.shared.play(.done)
            let doneMsg = isSearchTarget ? "Selesai, pencarian telah dilakukan." : "Selesai, teks telah diketik."
            await CompanionManager.shared.speakAndReportText(doneMsg)
        }
    }
}
