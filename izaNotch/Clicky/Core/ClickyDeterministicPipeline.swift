//
//  ClickyDeterministicPipeline.swift
//  izaNotch (Izanotchy)
//
//  3-Layer Deterministic Execution Architecture:
//  Lapis 1: Router (Derivasi Kategori: TUNJUK, AKSI, TANYA)
//  Lapis 2: Tools (Scoped per Kategori: ground_ax, ground_visual, fly_to, minta_consent, klik_fisik, verifikasi_visual)
//  Lapis 3: Rantai + Gate (Pengecekan lokal mikrodetik: in-screen bounds, consent, visual verification)
//

import AppKit
import CoreGraphics
import Defaults
import Foundation

// MARK: - Lapis 1: Kategori Perintah (Moved to Foundation L0: ClickyEnums.swift)


@MainActor
public final class ClickyDeterministicPipeline: ObservableObject {
    public static let shared = ClickyDeterministicPipeline()

    public private(set) var pendingConsentContinuation: CheckedContinuation<Bool, Never>?

    private init() {}

    // MARK: - Lapis 1: Router / Intent Derivation (0-Call, 0ms)

    public static func classifyCommandIntent(_ transcript: String) async -> ClickyCommandCategory {
        var t = transcript.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        // Strip greetings, salutations, and companion names
        let greetings = [
            "selamat pagi", "selamat siang", "selamat sore", "selamat malam",
            "halo", "hai", "hey", "hello", "hi", "clicky", "iza", "izanotchy"
        ]
        for g in greetings {
            t = t.replacingOccurrences(of: "\\b\(g)\\b", with: " ", options: .regularExpression)
        }
        t = t.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression).trimmingCharacters(in: .whitespaces)

        // 0. Domain-Specific Route: TradingView Commands
        let cleanSlash = t.replacingOccurrences(of: "^[/!]", with: "", options: .regularExpression).trimmingCharacters(in: .whitespaces)
        if let tvIntent = TradingViewCommandRouter.resolveTradingViewIntent(cleanSlash: cleanSlash, rawTranscript: t) {
            return tvIntent
        }

        // Action verbs (ordered from longest phrase to shortest)
        let actionVerbs: [(phrase: String, canon: String)] = [
            ("terus klik", "klik"), ("lalu klik", "klik"), ("kemudian klik", "klik"),
            ("terus buka", "buka"), ("lalu buka", "buka"), ("kemudian buka", "buka"),
            ("terus buat", "buat"), ("lalu buat", "buat"), ("kemudian buat", "buat"),
            ("klik", "klik"), ("click", "click"), ("pencet", "pencet"), ("tekan", "tekan"),
            ("ketik", "ketik"), ("type", "type"),
            ("tutup", "tutup"), ("close", "close"), ("quit", "quit"), ("keluar", "keluar"),
            ("buka", "buka"), ("open", "open"), ("launch", "launch"),
            ("buat", "buat"), ("bikin", "buat"), ("create", "buat"),
            ("tambah", "tambah"), ("add", "tambah"),
            ("hapus", "hapus"), ("delete", "delete")
        ]

        // Tunjuk triggers (ordered from longest phrase to shortest)
        let tunjukTriggers = [
            "yang mana", "sebelah mana", "di sebelah mana",
            "di mana", "dimana", "mana", "where is", "where's",
            "tunjukkan", "tunjuk", "show me", "point to"
        ]

        // 1. Check for action verb
        var foundVerbPhrase: String? = nil
        var canonicalAction: String? = nil
        for entry in actionVerbs {
            if t.contains(entry.phrase) {
                foundVerbPhrase = entry.phrase
                canonicalAction = entry.canon
                break
            }
        }

        if let verb = foundVerbPhrase, let action = canonicalAction {
            var cleaned = t.replacingOccurrences(of: verb, with: " ")
            for trig in tunjukTriggers {
                cleaned = cleaned.replacingOccurrences(of: trig, with: " ")
            }
            let fillers = [
                "tolong", "bisa tolong", "tolong dong", "please", "coba", "terus", "lalu", "kemudian", "dan",
                "dong", "ya", "sih", "nih", "deh", "kan", "lah", "bisa", "mau", "aplikasi", "app"
            ]
            for filler in fillers {
                cleaned = cleaned.replacingOccurrences(of: "\\b\(filler)\\b", with: " ", options: .regularExpression)
            }
            if action != "ketik" && action != "type" {
                cleaned = cleaned.replacingOccurrences(of: "[,.\\?!'\"“”‘’`]", with: " ", options: .regularExpression)
            }
            cleaned = cleaned.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression).trimmingCharacters(in: .whitespaces)
            let target = cleaned.isEmpty ? t : cleaned
            return .aksi(actionType: action, target: target)
        }

        // 2. Evaluasi Semantik Siri AI untuk Perintah "Cari" / "Search" / "Find" (Opsi 3)
        let isCariQuery = t.contains("cari") || t.contains("carikan") || t.contains("search") || t.contains("find")
        if isCariQuery {
            let intent = await SiriAIEngine.shared.parseTypingIntent(command: t)
            let trimmedText = intent.textToType.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedText.isEmpty {
                // Terdeteksi sebagai aksi pencarian konten (mengetik ke search bar atau kolom pencarian aplikasi)
                ClickyLogger.info("[PIPELINE]", "Siri AI classified 'cari' as typing/search intent: app=\(intent.appName ?? "none"), field=\(intent.targetField ?? "none"), text='\(trimmedText)'")
                return .aksi(actionType: "ketik", target: trimmedText)
            } else {
                // Terdeteksi sebagai perintah menunjuk letak tombol fisik / elemen UI (misal "cari tombol save", "cari ikon wifi")
                ClickyLogger.info("[PIPELINE]", "Siri AI classified 'cari' as UI pointing intent")
                var cleaned = t
                for trig in ["carikan", "cari", "search", "find"] + tunjukTriggers {
                    cleaned = cleaned.replacingOccurrences(of: trig, with: " ")
                }
                let fillers = [
                    "tolong", "coba", "dong", "please", "bisa", "dan", "ya", "sih", "nih", "deh", "kan", "lah", "aplikasi", "app"
                ]
                for filler in fillers {
                    cleaned = cleaned.replacingOccurrences(of: "\\b\(filler)\\b", with: " ", options: .regularExpression)
                }
                cleaned = cleaned.replacingOccurrences(of: "[,.\\?!'\"“”‘’`]", with: " ", options: .regularExpression)
                cleaned = cleaned.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression).trimmingCharacters(in: .whitespaces)
                let target = cleaned.isEmpty ? t : cleaned
                return .tunjuk(target: target)
            }
        }

        // 3. Check for tunjuk trigger (yang mana, di mana, tunjukkan, dll)
        var foundTunjuk = false
        for trig in tunjukTriggers {
            if t.contains(trig) {
                foundTunjuk = true
                break
            }
        }

        if foundTunjuk {
            var cleaned = t
            for trig in tunjukTriggers {
                cleaned = cleaned.replacingOccurrences(of: trig, with: " ")
            }
            let fillers = [
                "tolong", "coba", "dong", "please", "bisa", "dan", "ya", "sih", "nih", "deh", "kan", "lah", "aplikasi", "app"
            ]
            for filler in fillers {
                cleaned = cleaned.replacingOccurrences(of: "\\b\(filler)\\b", with: " ", options: .regularExpression)
            }
            cleaned = cleaned.replacingOccurrences(of: "[,.\\?!'\"“”‘’`]", with: " ", options: .regularExpression)
            cleaned = cleaned.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression).trimmingCharacters(in: .whitespaces)
            let target = cleaned.isEmpty ? t : cleaned
            return .tunjuk(target: target)
        }

        // 4. Fallback to conversational chat (TANYA)
        return .tanya(query: transcript)
    }

    // MARK: - Lapis 2: Tools

    /// Fast-path accessibility element search
    func groundAX(target: String, workSurface: ActiveWorkSurface?) -> CGPoint? {
        if let ws = workSurface {
            let lower = target.lowercased()
            if lower.contains("close") || lower.contains("tutup") {
                return ws.trafficLightCloseCenter
            }
            if lower.contains("minimize") || lower.contains("kecil") {
                return ws.trafficLightMinimizeCenter
            }
        }
        ClickyLogger.info("[PIPELINE]", "ground_ax MISS for '\(target)'")
        return nil
    }

    /// High-precision visual grounding fallback via OpenAI Luna
    func groundVisual(target: String, capture: CompanionScreenCapture) async throws -> CGPoint? {
        let tempDir = FileManager.default.temporaryDirectory
        let snapURL = tempDir.appendingPathComponent("pipeline_ground_\(UUID().uuidString).jpg")
        try capture.imageData.write(to: snapURL)
        defer { try? FileManager.default.removeItem(at: snapURL) }

        ClickyLogger.info("[PIPELINE]", "ground_visual requesting Luna for '\(target)'...")
        let res = try await ChatGPTCodexVisionService.shared.queryCoordinates(
            imagePath: snapURL.path,
            targetElementPrompt: target
        )
        let pt = CGPoint(x: res.x, y: res.y)
        ClickyLogger.success("[PIPELINE]", "Luna grounded '\(target)' at (\(res.x), \(res.y))")
        return pt
    }

    /// Triggers the blue triangle cursor flight and halo
    func flyTo(point: CGPoint, label: String) {
        CompanionManager.shared.triggerVisualElementFlight(
            appKitScreenPoint: point,
            targetRadius: 24.0,
            elementLabel: label
        )
    }

    /// Requests user consent for physical computer use
    func mintaConsent(actionType: String, target: String, point: CGPoint) async -> Bool {
        if Defaults[.alwaysAllowComputerUse] || CompanionManager.shared.isTaskSessionPreApproved {
            ClickyLogger.info("[CONSENT]", "Consent auto-granted (Full Access or pre-approved session)")
            return true
        }

        let bodyText = "Clicky ingin melakukan aksi `\(actionType)` pada '\(target)' di posisi (\(Int(point.x)), \(Int(point.y))).\n\nApakah Anda mengizinkan?"
        let request = ComputerUseRequest(
            companionName: CompanionManager.shared.activeBuddy.name,
            companionMood: .happy,
            cloudColorHex: CompanionManager.shared.activeBuddy.avatarColorHex,
            ringColorHex: "#BAE6FD",
            heading: "Izin Aksi: \(actionType.capitalized)",
            bodyText: bodyText,
            payload: ComputerUseActionPayload(
                type: (actionType == "tutup" || actionType == "close" || actionType == "quit") ? .keyCombo : .click,
                targetCoordinate: point,
                targetApp: target,
                rawDetails: "\(actionType) \(target)"
            )
        )

        return await withCheckedContinuation { continuation in
            self.pendingConsentContinuation = continuation
            CompanionManager.shared.pendingComputerUseRequest = request
            ClickySoundEngine.shared.play(.question)
            NotchComputerUseConsentWindow.shared.show(with: request)
        }
    }

    /// Resumes the pending consent continuation from external button callbacks
    func resumePendingConsent(approved: Bool) {
        if let cont = pendingConsentContinuation {
            pendingConsentContinuation = nil
            cont.resume(returning: approved)
        }
    }

    /// Executes the physical action using the CUA agent arrow cursor
    func klikFisik(point: CGPoint, actionType: String, target: String, workSurface: ActiveWorkSurface?) async {
        let isClose = actionType == "tutup" || actionType == "close" || actionType == "quit"
        let isOpen = actionType == "buka" || actionType == "open" || actionType == "launch"

        // 1. Activate agent arrow cursor
        _ = try? await CuaDriverClient.shared.executeTool(name: "set_agent_cursor_enabled", arguments: ["enabled": true])

        // Convert AppKit point to CG screen coordinates (origin top-left)
        let screen = NSScreen.screens.first(where: { $0.frame.contains(point) }) ?? NSScreen.main ?? NSScreen.screens[0]
        let cgPoint = CGPoint(x: point.x, y: screen.frame.height - point.y)

        // 2. Glide agent cursor to target
        await CuaDriverClient.shared.glideAgentCursor(to: cgPoint)
        try? await Task.sleep(for: .milliseconds(180))

        if isClose {
            let appName = ComputerUsePhysicalExecutor.resolveTargetAppName(appName: target, details: target) ?? workSurface?.appName ?? target
            ClickyLogger.info("[PIPELINE]", "Executing deterministic app close for: \(appName)")
            _ = await ComputerUsePhysicalExecutor.shared.terminateOrCloseApplication(named: appName, pid: workSurface?.ownerPID)
        } else if isOpen {
            let appName = ComputerUsePhysicalExecutor.resolveTargetAppName(appName: target, details: target) ?? target
            ClickyLogger.info("[PIPELINE]", "Executing app launch at: (\(Int(cgPoint.x)), \(Int(cgPoint.y))) for: \(appName)")
            await ComputerUsePhysicalExecutor.shared.executeMoveAndClick(at: cgPoint, button: .left, clickCount: 1)
            if let installedApp = InstalledApplicationsResolver.shared.resolveApplication(query: target) {
                let config = NSWorkspace.OpenConfiguration()
                config.activates = true
                _ = try? await NSWorkspace.shared.openApplication(at: installedApp.bundleURL, configuration: config)
            } else {
                NSWorkspace.shared.launchApplication(appName)
            }
        } else {
            ClickyLogger.info("[PIPELINE]", "Executing physical mouse click at: (\(Int(cgPoint.x)), \(Int(cgPoint.y)))")
            await ComputerUsePhysicalExecutor.shared.executeMoveAndClick(at: cgPoint, button: .left, clickCount: 1)
        }

        // 3. Hide agent arrow cursor
        try? await Task.sleep(for: .milliseconds(150))
        _ = try? await CuaDriverClient.shared.executeTool(name: "set_agent_cursor_enabled", arguments: ["enabled": false])
    }

    /// Selective post-action visual verification
    func verifikasiVisual(actionType: String, target: String, workSurface: ActiveWorkSurface?) async -> Bool {
        let isClose = actionType == "tutup" || actionType == "close" || actionType == "quit"
        let isOpen = actionType == "buka" || actionType == "open" || actionType == "launch"

        if isClose {
            try? await Task.sleep(for: .milliseconds(400))
            let appName = ComputerUsePhysicalExecutor.resolveTargetAppName(appName: target, details: target) ?? workSurface?.appName ?? target
            let running = NSWorkspace.shared.runningApplications.contains(where: {
                $0.localizedName?.lowercased() == appName.lowercased()
            })
            return !running
        } else if isOpen {
            try? await Task.sleep(for: .milliseconds(400))
            let appName = ComputerUsePhysicalExecutor.resolveTargetAppName(appName: target, details: target) ?? target
            let running = NSWorkspace.shared.runningApplications.contains(where: {
                $0.localizedName?.lowercased().contains(appName.lowercased()) == true
            })
            return running
        }
        return true
    }

    // MARK: - Local Gate Helper

    func isInScreenBounds(_ point: CGPoint) -> Bool {
        NSScreen.screens.contains(where: { $0.frame.contains(point) })
    }

    // MARK: - Chained Multi-Step Command Decomposition

    static let chainedActionVerbs: [String] = [
        "buka", "open", "launch", "jalankan",
        "buat", "bikin", "create", "tambah", "add", "siapin",
        "klik", "click", "tekan", "pencet",
        "ketik", "type", "tulis",
        "tutup", "close", "quit", "keluar",
        "cari", "analisa", "analisis"
    ]

    static func splitChainedCommand(transcript: String) async -> [String] {
        let t = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return [] }

        // Fast-path guard: Slash commands and atomic commands are NEVER chained
        if t.hasPrefix("/") || t.hasPrefix("!") {
            return [t]
        }

        // 1. Analisis Ambiguitas & Deteksi Hilang Informasi ("Prinsip: Jika Bingung > Wajib Lempar ke Siri AI")
        let lower = t.lowercased()
        let hasConjunction = lower.contains("setelah itu") || lower.contains("lalu") || lower.contains("terus") || lower.contains("kemudian")
        let hasCompoundMarker = lower.contains("dengan judul") || lower.contains("berjudul") || lower.contains("bernama") ||
                                lower.contains("dengan isi") || lower.contains("isinya") || lower.contains("dengan pesan") || lower.contains("tentang")

        let (deterministicSteps, isLossySplit) = splitVerbAnchorWithLossCheck(t)

        let isAmbiguous = isLossySplit || hasCompoundMarker || (deterministicSteps.count <= 1 && (hasConjunction || t.count > 25))

        if isAmbiguous {
            ClickyLogger.info("[CHAIN]", "Ambiguity detected in transcript: '\(t)' (lossy: \(isLossySplit), compound: \(hasCompoundMarker), count: \(deterministicSteps.count)). Triggering Siri AI on-device fallback...")
            CompanionManager.shared.setIntermediateStatusText("Clicky sedang membedah langkah perintah...")

            if let aiSteps = await SiriAIEngine.shared.decomposeChainedInstructions(command: t), aiSteps.count > 1 {
                ClickyLogger.info("[CHAIN]", "Ambiguity resolved into \(aiSteps.count) steps via Siri AI on-device: \(aiSteps)")
                return aiSteps
            }
            ClickyLogger.warning("[CHAIN]", "Siri AI fallback unavailable or returned single step. Using loss-less deterministic safety net.")
        } else if deterministicSteps.count > 1 {
            ClickyLogger.info("[CHAIN]", "Split into \(deterministicSteps.count) steps via Verb-Anchor (fast-path): \(deterministicSteps)")
            return deterministicSteps
        }

        // 2. Safety Net Deterministik (Loss-Less Recovery: jangan pernah membuang teks pengguna)
        let safeSteps = lossLessDeterministicRecovery(text: t, initialSteps: deterministicSteps)
        if safeSteps.count > 1 {
            ClickyLogger.info("[CHAIN]", "Recovered into \(safeSteps.count) steps via loss-less deterministic safety net: \(safeSteps)")
            return safeSteps
        }

        return [t]
    }

    private static func splitVerbAnchorWithLossCheck(_ text: String) -> (steps: [String], isLossy: Bool) {
        // Perlindungan payload 'ketik': segala teks setelah 'ketik'/'type'/'tulis' tidak boleh dipotong
        let ketikPattern = "\\b(?:lalu\\s+|terus\\s+|kemudian\\s+|setelah itu\\s+|dan\\s+)?(ketik|type|tulis)\\b"
        if let ketikRange = text.range(of: ketikPattern, options: [.regularExpression, .caseInsensitive]) {
            let beforeKetik = String(text[..<ketikRange.lowerBound]).trimmingCharacters(in: .whitespaces)
            let ketikPart = String(text[ketikRange.lowerBound...]).trimmingCharacters(in: .whitespaces)

            let cleanKetik = ketikPart.replacingOccurrences(of: "^(?:lalu|terus|kemudian|setelah itu|dan)\\s+", with: "", options: [.regularExpression, .caseInsensitive])

            var steps: [String] = []
            var lossy = false
            if !beforeKetik.isEmpty {
                let (nonKetikSteps, wasLossy) = splitNonKetikPartsWithLossCheck(beforeKetik)
                steps.append(contentsOf: nonKetikSteps)
                if wasLossy { lossy = true }
            }
            if !cleanKetik.isEmpty {
                steps.append(cleanKetik)
            }
            return (steps.filter { !$0.isEmpty }, lossy)
        }

        return splitNonKetikPartsWithLossCheck(text)
    }

    private static func splitNonKetikPartsWithLossCheck(_ text: String) -> (steps: [String], isLossy: Bool) {
        var t = text
        let leadingFillers = ["tolong", "bisa tolong", "tolong dong", "please", "coba", "hai", "halo", "hey"]
        for f in leadingFillers {
            t = t.replacingOccurrences(of: "^\\b\(f)\\b\\s*", with: "", options: [.regularExpression, .caseInsensitive])
        }
        t = t.replacingOccurrences(of: "[,;]\\s*", with: "|", options: .regularExpression)
        t = t.replacingOccurrences(of: "\\b(?:terus|lalu|kemudian|setelah itu)\\b", with: "|", options: [.regularExpression, .caseInsensitive])
        let verbsRegex = chainedActionVerbs.joined(separator: "|")
        t = t.replacingOccurrences(of: "\\bdan\\s+(?=(?:" + verbsRegex + ")\\b)", with: "|", options: [.regularExpression, .caseInsensitive])
        let verbPattern = "(?<=\\S)\\s+(?=(?:" + verbsRegex + ")\\b)"
        t = t.replacingOccurrences(of: verbPattern, with: "|", options: [.regularExpression, .caseInsensitive])

        let rawParts = t.components(separatedBy: "|")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .map { $0.replacingOccurrences(of: "^(?:tolong|bisa tolong|coba|dan)\\s+", with: "", options: [.regularExpression, .caseInsensitive]) }
            .filter { !$0.isEmpty }

        let filtered = rawParts.filter { part in
            let lower = part.lowercased()
            return chainedActionVerbs.contains { lower.contains($0) } && part.count >= 3
        }

        // Jika jumlah bagian sebelum filter > jumlah bagian yang lolos, artinya ada segmen bermakna yang hilang (lossy)
        let isLossy = !filtered.isEmpty && rawParts.count > filtered.count
        return (filtered, isLossy)
    }

    private static func lossLessDeterministicRecovery(text: String, initialSteps: [String]) -> [String] {
        var t = text
        let leadingFillers = ["tolong", "bisa tolong", "tolong dong", "please", "coba", "hai", "halo", "hey"]
        for f in leadingFillers {
            t = t.replacingOccurrences(of: "^\\b\(f)\\b\\s*", with: "", options: [.regularExpression, .caseInsensitive])
        }

        // Deteksi pola compound payload "dengan judul <X>" / "berjudul <X>"
        let judulPattern = "\\b(?:dengan\\s+judul|berjudul|dengan\\s+isi|isinya)\\s+(.+)$"
        if let regex = try? NSRegularExpression(pattern: judulPattern, options: .caseInsensitive),
           let match = regex.firstMatch(in: t, options: [], range: NSRange(location: 0, length: t.utf16.count)) {
            if let titleRange = Range(match.range(at: 1), in: t),
               let fullMatchRange = Range(match.range(at: 0), in: t) {
                let title = String(t[titleRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                let beforeJudul = String(t[..<fullMatchRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)

                var steps: [String] = []
                if !beforeJudul.isEmpty {
                    let (subSteps, _) = splitVerbAnchorWithLossCheck(beforeJudul)
                    steps.append(contentsOf: subSteps.isEmpty ? [beforeJudul] : subSteps)
                }
                if !title.isEmpty {
                    steps.append("ketik \(title)")
                }
                if steps.count > 1 {
                    return steps
                }
            }
        }

        // Penanganan segmen konjungsi di mana segmen akhir tidak memiliki kata kerja eksplisit
        t = t.replacingOccurrences(of: "[,;]\\s*", with: "|", options: .regularExpression)
        t = t.replacingOccurrences(of: "\\b(?:terus|lalu|kemudian|setelah itu)\\b", with: "|", options: [.regularExpression, .caseInsensitive])
        let verbsRegex = chainedActionVerbs.joined(separator: "|")
        t = t.replacingOccurrences(of: "\\bdan\\s+(?=(?:" + verbsRegex + ")\\b)", with: "|", options: [.regularExpression, .caseInsensitive])

        let rawParts = t.components(separatedBy: "|")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .map { $0.replacingOccurrences(of: "^(?:tolong|bisa tolong|coba|dan)\\s+", with: "", options: [.regularExpression, .caseInsensitive]) }
            .filter { !$0.isEmpty }

        guard rawParts.count > 1 else { return initialSteps }

        var recovered: [String] = []
        for (idx, part) in rawParts.enumerated() {
            let lower = part.lowercased()
            let hasVerb = chainedActionVerbs.contains { lower.contains($0) }
            if hasVerb {
                recovered.append(part)
            } else if idx > 0 && part.count >= 2 {
                // Segmen tanpa kata kerja yang mengikuti aksi lain otomatis dijadikan aksi ketik
                recovered.append("ketik \(part)")
            } else {
                recovered.append(part)
            }
        }

        return recovered.filter { !$0.isEmpty }
    }

}
