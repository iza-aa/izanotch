//
//  ClickyDeterministicPipeline.swift
//  boringNotch (Izanotchy)
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

// MARK: - Lapis 1: Kategori Perintah
public enum ClickyCommandCategory: Equatable, Sendable {
    case tunjuk(target: String)
    case aksi(actionType: String, target: String)
    case tanya(query: String)
}

// MARK: - Installed Applications Dynamic Discovery & Resolver (Opsi A)

public struct InstalledApplication: Sendable {
    public let displayName: String
    public let bundleURL: URL
    public let bundleIdentifier: String?
}

public typealias DynamicAppResolver = InstalledApplicationsResolver

public final class InstalledApplicationsResolver: @unchecked Sendable {
    public static let shared = InstalledApplicationsResolver()

    public private(set) var cachedApps: [InstalledApplication] = []
    private var lastScanTime: Date = .distantPast
    private let lock = NSLock()

    private init() {
        refreshCache()
    }

    public func refreshCache() {
        lock.lock()
        defer { lock.unlock() }

        var results: [InstalledApplication] = []
        var seenURLs = Set<URL>()

        let directories = [
            "/Applications",
            "/System/Applications",
            "/System/Applications/Utilities",
            "/System/Cryptexes/App/System/Applications",
            NSHomeDirectory() + "/Applications"
        ]

        let fm = FileManager.default
        for dir in directories {
            guard let items = try? fm.contentsOfDirectory(atPath: dir) else { continue }
            for item in items {
                if item.hasSuffix(".app") {
                    let fullPath = dir + "/" + item
                    let url = URL(fileURLWithPath: fullPath)
                    if seenURLs.insert(url).inserted {
                        let name = url.deletingPathExtension().lastPathComponent
                        let bundle = Bundle(url: url)
                        let bundleId = bundle?.bundleIdentifier
                        let displayName = (bundle?.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
                            ?? (bundle?.object(forInfoDictionaryKey: "CFBundleName") as? String)
                            ?? name
                        results.append(InstalledApplication(
                            displayName: displayName,
                            bundleURL: url,
                            bundleIdentifier: bundleId
                        ))
                    }
                } else if !item.hasPrefix(".") {
                    // Check 1 level of subdirectories (e.g. DaVinci Resolve, Python, etc.)
                    let sub = dir + "/" + item
                    var isDir: ObjCBool = false
                    if fm.fileExists(atPath: sub, isDirectory: &isDir), isDir.boolValue {
                        if let subItems = try? fm.contentsOfDirectory(atPath: sub) {
                            for s in subItems where s.hasSuffix(".app") {
                                let fullPath = sub + "/" + s
                                let url = URL(fileURLWithPath: fullPath)
                                if seenURLs.insert(url).inserted {
                                    let name = url.deletingPathExtension().lastPathComponent
                                    let bundle = Bundle(url: url)
                                    let bundleId = bundle?.bundleIdentifier
                                    let displayName = (bundle?.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
                                        ?? (bundle?.object(forInfoDictionaryKey: "CFBundleName") as? String)
                                        ?? name
                                    results.append(InstalledApplication(
                                        displayName: displayName,
                                        bundleURL: url,
                                        bundleIdentifier: bundleId
                                    ))
                                }
                            }
                        }
                    }
                }
            }
        }

        self.cachedApps = results
        self.lastScanTime = Date()
        ClickyLogger.info("[APP_RESOLVER]", "Scanned and cached \(results.count) installed applications dynamically")
    }

    /// Resolves a user query (e.g. "trading view", "safari", "google chrome") to a matching installed application
    public func resolveApplication(query: String) -> InstalledApplication? {
        lock.lock()
        // Refresh every 5 minutes or if empty
        if Date().timeIntervalSince(lastScanTime) > 300 || cachedApps.isEmpty {
            lock.unlock()
            refreshCache()
            lock.lock()
        }
        let apps = cachedApps
        lock.unlock()

        let rawQuery = query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanedQuery = rawQuery.replacingOccurrences(of: "\\b(?:aplikasi|app)\\b", with: " ", options: [.regularExpression, .caseInsensitive])
        let normalizedQuery = cleanedQuery.filter { $0.isLetter || $0.isNumber }
        if normalizedQuery.isEmpty { return nil }

        // Pass 1: Exact match on normalized alphanumeric string
        for app in apps {
            let normName = app.displayName.lowercased().filter { $0.isLetter || $0.isNumber }
            if normName == normalizedQuery { return app }
            let normLastPath = app.bundleURL.deletingPathExtension().lastPathComponent.lowercased().filter { $0.isLetter || $0.isNumber }
            if normLastPath == normalizedQuery { return app }
        }

        // Pass 2: Prefix match on normalized string
        for app in apps {
            let normName = app.displayName.lowercased().filter { $0.isLetter || $0.isNumber }
            if normName.hasPrefix(normalizedQuery) || normalizedQuery.hasPrefix(normName) { return app }
        }

        // Pass 3: Substring match on query
        for app in apps {
            let normName = app.displayName.lowercased().filter { $0.isLetter || $0.isNumber }
            if normName.contains(normalizedQuery) || normalizedQuery.contains(normName) { return app }
        }

        // Pass 4: Common aliases dictionary
        let aliases: [String: String] = [
            "chrome": "googlechrome",
            "vscode": "visualstudiocode",
            "code": "visualstudiocode",
            "settings": "systemsettings",
            "pengaturan": "systemsettings",
            "terminal": "terminal",
            "pesan": "messages",
            "catatan": "notes",
            "kalkulator": "calculator"
        ]
        if let targetAlias = aliases[normalizedQuery] {
            for app in apps {
                let normName = app.displayName.lowercased().filter { $0.isLetter || $0.isNumber }
                if normName == targetAlias || normName.contains(targetAlias) { return app }
            }
        }

        return nil
    }
}

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
        let isLossy = rawParts.count > filtered.count
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
