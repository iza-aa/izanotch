//
//  CompanionManager+FlightParser.swift
//  izaNotch (Izanotchy)
//
//  Decomposed extension for CompanionManager.
//

import AppKit
import AVFoundation
import Combine
import CoreGraphics
import Defaults
import Foundation
import ClickyFoundation
import ClickyPlatform
import ClickyAIProviders
import ClickySpeech
import ClickyCUA
import ClickyReasoning
import ClickyAstronacci
import ClickyTradingView
import ClickyFuturesScout
import ClickyRoster
import ClickyDesignSystem

extension CompanionManager {
    // MARK: - Point Tag Parsing

    /// Result of parsing a [CANDIDATE:...], [TARGET:...] or [POINT:...] tag.
    struct PointingParseResult {
        /// The response text with the pointing tag removed — this is what gets spoken.
        let spokenText: String
        /// Stable OS-truth candidate id from [CANDIDATE:<id>:<label>], if present.
        let candidateId: String?
        /// The parsed pixel coordinate, or nil if none was found.
        let coordinate: CGPoint?
        /// Target halo radius in points
        let targetRadius: CGFloat
        /// Short label describing the element (e.g. "close button"), or "none".
        let elementLabel: String?
        /// Which screen the coordinate refers to (1-based), or nil to default to cursor screen.
        let screenNumber: Int?
        /// Normalized 0-1000 bounding box (Gemini spatial grounding: ymin, xmin, ymax, xmax)
        let normalizedBox: (ymin: Double, xmin: Double, ymax: Double, xmax: Double)?
    }

    /// Plan sinkron-teks (2026-09-22): baris TARGET yang TERMINASI newline adalah
    /// sinyal flight awal yang aman. Bedakan "lengkap" (ada \n penutup) dari "matang"
    /// (isMatureTargetExpression). Chunk parsial "Red circle in bottom..." (tanpa \n)
    /// DITOLAK walau matang — itulah yang menembak dock-safari 3x (10:39/10:51/11:23).
    /// Kembalikan expression bila baris TARGET sudah terminasi, else nil.
    static func terminatedTargetLine(in text: String) -> String? {
        // Plan perbaikan 22 Sep (Bug A): syarat \\n MEMBUNUH early-flight — AFM
        // streaming fragmen token tanpa newline sampai kalimat kedua jalan.
        // Terminasi = baris TARGET LENGKAP (akhir-string ATAU \\n). Parsial yang
        // masih diketik (tanpa terminasi) tetap ditolak — bedakan via $ vs \\n.
        let pattern = #"(?im)^[ \t]*TARGET:[ \t]*(.+?)[ \t]*(?:\n|$)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              match.numberOfRanges >= 2,
              let r = Range(match.range(at: 1), in: text) else { return nil }
        let expr = String(text[r]).trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
        guard !expr.isEmpty else { return nil }
        return expr
    }

    /// Opsi D Fase 2: planner referring expression — satu baris "TARGET: <Long-RE>".
    /// Dipanggil di streaming (akumulator) DAN di akhir turn (final, lawan reorder).
    /// Kembalikan expression mentah (tanpa prefix), atau nil bila tidak ada.
    static func parseTargetExpression(from responseText: String) -> String? {
        let pattern = #"(?im)^[ \t]*TARGET:[ \t]*(.+?)[ \t]*$"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []),
              let match = regex.firstMatch(in: responseText, range: NSRange(responseText.startIndex..., in: responseText)),
              match.numberOfRanges >= 2,
              let r = Range(match.range(at: 1), in: responseText) else { return nil }
        let expr = String(responseText[r]).trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
        guard !expr.isEmpty else { return nil }
        return expr
    }

    /// DELETED (Hotfix #9): enrichment menempel frontmost-app yang salah.
    /// Pemanggil terakhir dimigrasikan ke Fixed (identitas). Jangan hidupkan lagi.
    /// @deprecated Gunakan enrichTargetExpressionFixed (identitas, tanpa append).
    static func enrichTargetExpression(_ expr: String, workSurface: ActiveWorkSurface?) -> String {
        let lower = expr.lowercased()
        if let ws = workSurface, !ws.appName.isEmpty,
           !lower.contains(ws.appName.lowercased()) && !lower.contains("window") && !lower.contains("screen") && !lower.contains("dock") {
            return "\(expr) in \(ws.appName) window"
        }
        return expr
    }

    /// Hotfix live-test 2026-09-22 (2 bug):
    /// (1) Intent gate — sapaan ("halo") tanpa intensi tunjuk TIDAK boleh terbang,
    ///     walau model keluarkan [CANDIDATE:]/[POINT:]/TARGET:. Tanpa gate ini,
    ///     cabang pasif [CANDIDATE:] menerbangkan kursor untuk chat biasa.
    ///     Deteksi: model chat tidak boleh lagi keluarkan angka — tapi sebelum Fase 4
    ///     (SoM legend masih dikirim) model masih bisa emit bracket tags; gate ini
    ///     menahan flight untuk transkrip non-spasial.
    /// (2) Enrichment menimpa app yang disebut model ("...Autodraw window" + "in Safari
    ///     window") -> rarity cocok ke dock-safari yang salah. Perbaikan: JANGAN append
    ///     bila RE sudah menyebut NAMA APP APAPUN yang sedang berjalan (bukan hanya
    ///     ws.appName), dan jangan append bila RE sudah sebut wilayah (window/screen/dock).
    static func hasPointingIntent(transcript: String) -> Bool {
        let t = transcript.lowercased()
        // Verba/objek spasial ID + EN. Sapaan ("halo", "hai", "hello", "thanks",
        // "apa kabar") tidak mengandung satupun -> gate menolak.
        let markers = ["mana", "dimana", "tunjuk", "tunjukkan", "tunj", "klik", "tombol",
            "ikon", "icon", "lingkaran", "kotak", "gambar", "bentuk", "warna", "merah",
            "kuning", "hijau", "biru", "oranye", "cari", "letak", "posisi", "sebelah",
            "pojok", "atas", "bawah", "kiri", "kanan", "tengah", "jendela", "window",
            "button", "circle", "square", "shape", "color", "red", "yellow", "green",
            "blue", "orange", "where", "which", "show", "point", "click", "close",
            "tutup", "buka", "zoom", "dock", "menu", "tab", "teks", "text"]
        return markers.contains(where: { t.contains($0) })
    }

    /// Nama app berjalan yang disebut di RE (untuk enrichment fix #2).
    static func mentionedRunningApp(in lowerExpr: String) -> String? {
        for app in NSWorkspace.shared.runningApplications {
            guard app.activationPolicy == .regular,
                  app.bundleIdentifier != Bundle.main.bundleIdentifier,
                  let name = app.localizedName, name.count >= 3 else { continue }
            if lowerExpr.contains(name.lowercased()) { return name }
        }
        return nil
    }

    /// Hotfix live-test #2 (2026-09-22 10:39): flight prematur dari expression
    /// PARSIAL. Chunk pertama ("red...") + enrichment ("in Safari window") langsung
    /// cocok rarity ke dock-safari dan mengunci latch — expression lengkap yang benar
    /// ("red circle ... Autodraw window") datang 1 dtk kemudian tapi diabaikan.
    /// Aturan matang: expression minimal 3 token DAN mengandung kata benda objek
    /// (bukan cuma sifat/wilayah). Belum matang = tunggu chunk berikutnya; flight
    /// diputuskan di akhir turn dari expression final. Dock/traffic tidak dikecualikan:
    /// kasus 10:39 membuktikan pengecualian itu yang justru menembak salah.
    /// Hotfix live-test #3 (2026-09-22 10:51): expression PARSIAL yang lolos maturity
    /// ("Red circle with" + enrichment "in Safari window") mengunci latch padahal final
    /// ("Red circle ... Autodraw window") beda total. Aturan: flight streaming BUKAN
    /// final — ia hanya "pinjaman" yang HARUS dikembalikan bila final tak sepakat.
    /// Kesepakatan = token-intersection final vs yang dipakai flight >= 60% token final
    /// (stopword-free, len>=3). Di bawah itu = flight salah sasaran -> clear + flight ulang.
    static func targetExpressionsAgree(_ flown: String, _ final: String) -> Bool {
        func toks(_ s: String) -> Set<String> {
            Set(s.lowercased().split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(String.init).filter { $0.count >= 3 })
        }
        let a = toks(flown), b = toks(final)
        guard !b.isEmpty else { return true }
        let inter = a.intersection(b).count
        return Double(inter) / Double(b.count) >= 0.6
    }

    static func isMatureTargetExpression(_ expr: String) -> Bool {
        let toks = expr.lowercased().split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(String.init).filter { $0.count >= 3 }
        guard toks.count >= 3 else { return false }
        let objectNouns = ["circle", "lingkaran", "button", "tombol", "icon", "ikon",
            "window", "jendela", "menu", "tab", "dock", "square", "kotak", "shape",
            "bentuk", "text", "teks", "image", "gambar", "field", "slider", "checkbox",
            "link", "close", "tutup", "minimize", "zoom", "trash", "finder", "safari",
            "whatsapp", "terminal", "spot", "search", "create", "rovo",
            "dot", "titik", "spot", "cluster", "sidebar", "panel", "bar", "logo",
            "triangle", "segitiga", "ring", "cincin", "box", "kotak"]
        return toks.contains(where: { objectNouns.contains($0) })
    }

    /// Hotfix #9 (2026-09-22 13:14, BUKTI + SIMULASI): enrichment DIHAPUS TOTAL.
    /// "in Safari window" (frontmost) adalah satu-satunya token yang cocok ke kandidat
    /// (simulasi: DENGAN enrichment dock-safari menang 3.4; TANPA = semua 0.0 = MISS).
    /// Frontmost app TIDAK sama dengan app yang dimaksud user (Autodraw di belakang
    /// Safari saat bicara). Konteks OS disuntik ke PROMPT planner (bukan ke expression),
    /// dan planner yang putuskan menyebut app apa. Fungsi dipertahankan sebagai
    /// identitas agar call-site tak berubah.
    static func enrichTargetExpressionFixed(_ expr: String, workSurface: ActiveWorkSurface?) -> String {
        return expr
    }

    /// Parses [CANDIDATE:<id>:<label>], [TARGET:ymin,xmin,ymax,xmax:label], [TARGET:x,y,r:label], or [POINT:x,y:label:screenN].
    static func parsePointingCoordinates(from responseText: String) -> PointingParseResult {
        let quoteAndWhitespace = CharacterSet(charactersIn: "\"\'").union(.whitespacesAndNewlines)
        let trimmedResponse = responseText.trimmingCharacters(in: quoteAndWhitespace)

        // 0. Stage 2 candidate tag: [CANDIDATE:<id>:<label>] — model selects, OS resolves.
        let candidatePattern = #"(?i)\[CANDIDATE:([A-Za-z0-9_\-]+)(?::([^\]:]*?))?\]"#
        if let candRegex = try? NSRegularExpression(pattern: candidatePattern, options: []),
           let candMatch = candRegex.firstMatch(in: trimmedResponse, range: NSRange(trimmedResponse.startIndex..., in: trimmedResponse)),
           let idRange = Range(candMatch.range(at: 1), in: trimmedResponse) {
            let cid = String(trimmedResponse[idRange])
            var candLabel: String? = nil
            if candMatch.numberOfRanges >= 3, let lr = Range(candMatch.range(at: 2), in: trimmedResponse) {
                let l = String(trimmedResponse[lr]).trimmingCharacters(in: .whitespaces)
                if !l.isEmpty { candLabel = l }
            }
            let cleaned = candRegex.stringByReplacingMatches(
                in: trimmedResponse, options: [],
                range: NSRange(trimmedResponse.startIndex..., in: trimmedResponse),
                withTemplate: ""
            ).trimmingCharacters(in: quoteAndWhitespace)
            let spoken = !cleaned.isEmpty ? cleaned : (candLabel != nil ? "\(candLabel!) right here!" : "this way!")
            return PointingParseResult(spokenText: spoken, candidateId: cid, coordinate: nil, targetRadius: 28.0, elementLabel: candLabel, screenNumber: nil, normalizedBox: nil)
        }

        // 1. Check for normalized 4-value bounding box: [TARGET:ymin,xmin,ymax,xmax:label] or [BOX:ymin,xmin,ymax,xmax:label]
        let boxPattern = #"(?i)\[(?:TARGET|POINT|BOX):(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)(?::([^\]:\s][^\]:]*?))?(?::screen(\d+))?\]"#
        if let boxRegex = try? NSRegularExpression(pattern: boxPattern, options: []),
           let match = boxRegex.firstMatch(in: trimmedResponse, range: NSRange(trimmedResponse.startIndex..., in: trimmedResponse)) {
            let cleanedText = boxRegex.stringByReplacingMatches(
                in: trimmedResponse,
                options: [],
                range: NSRange(trimmedResponse.startIndex..., in: trimmedResponse),
                withTemplate: ""
            ).trimmingCharacters(in: quoteAndWhitespace)

            if match.numberOfRanges >= 5,
               let yminRange = Range(match.range(at: 1), in: trimmedResponse),
               let xminRange = Range(match.range(at: 2), in: trimmedResponse),
               let ymaxRange = Range(match.range(at: 3), in: trimmedResponse),
               let xmaxRange = Range(match.range(at: 4), in: trimmedResponse),
               let ymin = Double(trimmedResponse[yminRange]),
               let xmin = Double(trimmedResponse[xminRange]),
               let ymax = Double(trimmedResponse[ymaxRange]),
               let xmax = Double(trimmedResponse[xmaxRange]) {
                var elementLabel: String? = nil
                if match.numberOfRanges >= 6, let labelRange = Range(match.range(at: 5), in: trimmedResponse) {
                    let label = String(trimmedResponse[labelRange]).trimmingCharacters(in: .whitespaces)
                    if !label.isEmpty { elementLabel = label }
                }
                var screenNumber: Int? = nil
                if match.numberOfRanges >= 7, let screenRange = Range(match.range(at: 6), in: trimmedResponse) {
                    screenNumber = Int(trimmedResponse[screenRange])
                }
                let finalSpokenText = !cleanedText.isEmpty ? cleanedText : (elementLabel != nil ? "\(elementLabel!) right here!" : "this way!")
                return PointingParseResult(
                    spokenText: finalSpokenText,
                    candidateId: nil,
                    coordinate: CGPoint(x: (xmin + xmax) / 2.0, y: (ymin + ymax) / 2.0),
                    targetRadius: 30.0,
                    elementLabel: elementLabel,
                    screenNumber: screenNumber,
                    normalizedBox: (ymin: ymin, xmin: xmin, ymax: ymax, xmax: xmax)
                )
            }
        }

        // 2. Check for standard 2 or 3 value pixel format: [TARGET:x,y,r:label] or [POINT:x,y:label]
        let pattern = #"(?i)\[(?:TARGET|POINT):(?:none|(\d+)\s*,\s*(\d+)(?:\s*,\s*(\d+))?(?::([^\]:\s][^\]:]*?))?(?::screen(\d+))?)\]"#

        guard let regex = try? NSRegularExpression(pattern: pattern, options: []),
              let match = regex.firstMatch(in: trimmedResponse, range: NSRange(trimmedResponse.startIndex..., in: trimmedResponse)) else {
            return PointingParseResult(spokenText: trimmedResponse, candidateId: nil, coordinate: nil, targetRadius: 35.0, elementLabel: nil, screenNumber: nil, normalizedBox: nil)
        }

        let cleanedText = regex.stringByReplacingMatches(
            in: trimmedResponse,
            options: [],
            range: NSRange(trimmedResponse.startIndex..., in: trimmedResponse),
            withTemplate: ""
        ).trimmingCharacters(in: quoteAndWhitespace)

        guard match.numberOfRanges >= 3,
              let xRange = Range(match.range(at: 1), in: trimmedResponse),
              let yRange = Range(match.range(at: 2), in: trimmedResponse),
              let x = Double(trimmedResponse[xRange]),
              let y = Double(trimmedResponse[yRange]) else {
            return PointingParseResult(spokenText: cleanedText, candidateId: nil, coordinate: nil, targetRadius: 35.0, elementLabel: "none", screenNumber: nil, normalizedBox: nil)
        }

        var targetRadius: CGFloat = 35.0
        if match.numberOfRanges >= 4, let rRange = Range(match.range(at: 3), in: trimmedResponse), let r = Double(trimmedResponse[rRange]) {
            targetRadius = CGFloat(r)
        }

        var elementLabel: String? = nil
        if match.numberOfRanges >= 5, let labelRange = Range(match.range(at: 4), in: trimmedResponse) {
            let label = String(trimmedResponse[labelRange]).trimmingCharacters(in: .whitespaces)
            if !label.isEmpty {
                elementLabel = label
            }
        }

        var screenNumber: Int? = nil
        if match.numberOfRanges >= 6, let screenRange = Range(match.range(at: 5), in: trimmedResponse) {
            screenNumber = Int(trimmedResponse[screenRange])
        }

        let finalSpokenText = !cleanedText.isEmpty ? cleanedText : (elementLabel != nil ? "\(elementLabel!) right here!" : "this way!")

        return PointingParseResult(
            spokenText: finalSpokenText,
            candidateId: nil,
            coordinate: CGPoint(x: x, y: y),
            targetRadius: targetRadius,
            elementLabel: elementLabel,
            screenNumber: screenNumber,
            normalizedBox: nil
        )
    }

    /// Strips any pointing, action, target, or candidate tags from text for clean subtitle, chat & TTS display
    /// Opsi D Fase 2: juga strip baris planner "TARGET: <expression>" agar tidak bocor ke TTS/subtitle.
    static func stripTechnicalTags(from text: String) -> String {
        // 0. Strip planner line: a full line starting with TARGET: (plain, no brackets).
        let plannerPattern = #"(?im)^[ \t]*TARGET:[ \t]*.+?[ \t]*$"#
        var cleaned = text
        if let regex = try? NSRegularExpression(pattern: plannerPattern, options: []) {
            cleaned = regex.stringByReplacingMatches(
                in: cleaned,
                options: [],
                range: NSRange(cleaned.startIndex..., in: cleaned),
                withTemplate: ""
            )
        }
        // 1. Strip completed bracket tags: [TARGET:...], [ACTION:...], [POINT:...], [BOX:...], [CANDIDATE:...], [REQUEST_FEATURE:...], etc.
        let fullTagPattern = #"(?i)\[(?:TARGET|POINT|BOX|ACTION|CANDIDATE|REQUEST_FEATURE):[^\]]*\]"#
        if let regex = try? NSRegularExpression(pattern: fullTagPattern, options: []) {
            cleaned = regex.stringByReplacingMatches(
                in: cleaned,
                options: [],
                range: NSRange(cleaned.startIndex..., in: cleaned),
                withTemplate: ""
            )
        }

        // 2. Strip XML/HTML tags: <COMPUTER_USE_REQUEST>...</COMPUTER_USE_REQUEST> or generic <...>
        let xmlPattern = #"(?is)<COMPUTER_USE_REQUEST>.*?</COMPUTER_USE_REQUEST>|<[^>]+>"#
        if let xmlRegex = try? NSRegularExpression(pattern: xmlPattern, options: []) {
            cleaned = xmlRegex.stringByReplacingMatches(
                in: cleaned,
                options: [],
                range: NSRange(cleaned.startIndex..., in: cleaned),
                withTemplate: ""
            )
        }

        // 3. Strip trailing unclosed tag during live streaming (e.g. "[ACTION:tv_time..." or "<COMPUTER_USE...")
        if let lastOpenBracket = cleaned.lastIndex(of: "[") {
            let suffix = cleaned[lastOpenBracket...]
            if !suffix.contains("]") && (suffix.lowercased().contains("action") || suffix.lowercased().contains("target") || suffix.lowercased().contains("candidate") || suffix.lowercased().contains("point") || suffix.lowercased().contains("request_feature")) {
                cleaned = String(cleaned[..<lastOpenBracket])
            }
        }
        if let lastOpenAngle = cleaned.lastIndex(of: "<") {
            let suffix = cleaned[lastOpenAngle...]
            if !suffix.contains(">") && suffix.lowercased().contains("computer_use") {
                cleaned = String(cleaned[..<lastOpenAngle])
            }
        }

        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// SoM: replaces [POINT:]/[TARGET:]/[BOX:]/[CANDIDATE:] tags from a MISS turn
    /// with a neutral marker so history teaches format without wrong coordinates.
    /// Opsi D Fase 2: juga netralkan baris planner "TARGET: <expr>" yang miss.
    static func neutralizeMissTags(in text: String) -> String {
        // Hotfix #8 (2026-09-22): marker "[... removed — miss]" BOCOR ke chat user
        // karena stripTechnicalTags tidak kenal pola "[POINT removed — miss]".
        // Perbaikan: netralkan dengan MENGHAPUS tag (string kosong), bukan marker.
        // History tetap ajarkan format? Tidak — dengan planner TARGET:, history TIDAK
        // perlu contoh koordinat sama sekali. Hapus bersih = tidak bocor + tidak meracuni.
        let missPattern = #"(?i)\[(?:TARGET|POINT|BOX|CANDIDATE):[^\]]*\]"#
        var out = text
        if let rx = try? NSRegularExpression(pattern: missPattern, options: []) {
            out = rx.stringByReplacingMatches(in: out, options: [], range: NSRange(out.startIndex..., in: out), withTemplate: "")
        }
        let plannerMiss = #"(?im)^[ \t]*TARGET:[ \t]*.+?[ \t]*$"#
        if let rx = try? NSRegularExpression(pattern: plannerMiss, options: []) {
            out = rx.stringByReplacingMatches(in: out, options: [], range: NSRange(out.startIndex..., in: out), withTemplate: "")
        }
        return out
    }

    static func stripPointingTags(from text: String) -> String {
        return stripTechnicalTags(from: text)
    }

    /// Filters out raw Markdown table rows (| ... |) so TTS vocalizes natural conversational sentences smoothly
    static func stripTableForSpeech(from text: String) -> String {
        let lines = text.components(separatedBy: .newlines)
        let filtered = lines.filter { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            return !trimmed.hasPrefix("|")
        }
        let spoken = filtered.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        return spoken.isEmpty ? "I have prepared the trade setup table in your chat." : spoken
    }

}
