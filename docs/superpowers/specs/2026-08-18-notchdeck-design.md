# 📄 NOTCHDECK SPECIFICATION & ARCHITECTURE DESIGN DOCUMENT
**App Name:** NotchDeck (macOS Dynamic Island & Developer Command Center)  
**Target Platform:** macOS 14.0+ (Sonoma) & macOS 15.0+ (Sequoia)  
**Distribution:** Direct Notarized DMG (Non-App Store, Apple Developer ID signed)  
**Date:** 2026-08-18  
**Status:** VALIDATED & READY FOR IMPLEMENTATION PLAN  

---

## 1. System Overview & Executive Architecture

NotchDeck is a native macOS developer utility built with **Swift 6, SwiftUI, and AppKit**. It anchors a fluid, hardware-adaptive Dynamic Island HUD to the MacBook notch (and floats on external displays). 

### Core Capabilities
1. **Multi-AI Command Deck:** Subprocess & SDK-backed bridges to Antigravity, Claude, and Codex with transcript mirroring.
2. **Hybrid Voice & Smart Scheduler:** Offline `SFSpeechRecognizer` audio HUD + Dual-engine Scheduler (Cloud NLP + Local Regex/NSDataDetector Fallback) synced to **Apple EventKit** (Calendar & Reminders).
3. **Deterministic Verbal Voice-Over:** Instant, offline spoken alerts via `AVSpeechSynthesizer` with localized Indonesian phonetic number conversion.
4. **Smart Clipboard Hub & Dropzone:** Persistent clipboard history with strict 100% secret token masking and temporary drag-and-drop staging.

---

## 2. Hardware Notch & Windowing Engine (EPIC 1)

### 2.1 Windowing Architecture
* **Class:** `NotchPanel: NSPanel`
* **Window Level:** `.statusBar + 1`
* **Collection Behaviors:** `[.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]`
* **Style Mask:** `[.borderless, .nonactivatingPanel]`
* **Hardware Detection:** Reads `NSScreen.main?.auxiliaryTopLeftArea` and `safeAreaInsets.top`.
  * *MacBook Notch:* Anchors with curved side ears merging with menu bar.
  * *External Monitor:* Floats as a standalone Dynamic Island pill 10px below screen top.

### 2.2 Visual State Machine
* **`.collapsed`:** Width: 180px, Height: 32px. Standby pill with status dots. RAM target $\le 55\text{ MB}$.
* **`.voiceActive`:** Width: 360px, Height: 70px. Blue audio waveform (`||||||`) + live streaming transcript + Stop button.
* **`.liveActivity`:** Width: 320px, Height: 44px. Progress bar, countdown badge (`10m to Meeting`).
* **`.expanded`:** Width: 640px, Height: 460px. Full Command Bar + Model Selector + Filter Pills + Horizontal Card Carousel. Active RAM target $\le 120\text{ MB}$.

---

## 3. Multi-AI Bridge & Dispatcher Architecture (EPIC 2 - RE-ARCHITECTED)

### 3.1 Strategy & Phased Integration
Instead of unverified Accessibility GUI injection, NotchDeck employs standard, robust adapters:

```
┌────────────────────────────────────────────────────────────┐
│                  NotchDeck AI Coordinator                  │
├─────────────────────────────┬──────────────────────────────┤
│ 1. Antigravity Adapter      │ 2. Claude / Codex Adapters   │
│ - Local Transcript Watcher  │ - CLI Subprocess Execution   │
│   (~/.gemini/antigravity)   │   (Headless claude / codex)  │
│ - Official SDK / CLI Runner │ - AppleScript fallback       │
└─────────────────────────────┴──────────────────────────────┘
```

### 3.2 Technical Spike & Milestones
* **Phase 1 (MVP Target):** Antigravity CLI/SDK Integration & Local Transcript Watcher.
* **Phase 2:** Headless Claude Code CLI stream reader.
* **Phase 3:** Open-source Codex CLI runner.

---

## 4. Hybrid Scheduler & Speech Engine (EPIC 3 & 4)

### 4.1 Speech-to-Text Engine
* Uses `SFSpeechRecognizer(locale: Locale(identifier: "id-ID"))`.
* **Runtime Verification:** Checks `recognizer.supportsOnDeviceRecognition`. If false/missing, prompts user or falls back gracefully to standard online speech recognition.

### 4.2 Dual-Engine Schedule Parsing
1. **Primary (Online):** Cloud API (`Gemini 2.5 Flash`) with timeout at $1.5\text{s}$.
2. **Fallback (Offline / Timeout):** Native Swift `LocalScheduleParser` using regex rules and `NSDataDetector` (matches "jam 2", "10 menit lagi", "besok 09:00").

### 4.3 Deterministic Offline Voice-Over Generator (Zero LLM Dependency)
Spoken alerts are built locally in Swift to guarantee 0ms latency and 100% offline reliability:

```swift
public struct LocalVoiceOverBuilder {
    public static func buildScript(title: String, offsetMinutes: Int) -> String {
        let numberWords = ["0": "nol", "1": "satu", "2": "dua", "3": "tiga", "4": "empat", "5": "lima", "10": "sepuluh", "15": "lima belas", "20": "dua puluh", "30": "tiga puluh"]
        let offsetStr = numberWords[String(offsetMinutes)] ?? "\(offsetMinutes)"
        
        if offsetMinutes == 0 {
            return "Pengingat: Agenda \(title) dimulai sekarang."
        } else {
            return "Pengingat: Agenda \(title) akan dimulai dalam \(offsetStr) menit."
        }
    }
}
```

---

## 5. Security, Secrets & macOS Permissions Matrix

### 5.1 Permissions Matrix
| Permission | Info.plist Key | Purpose | Required For |
| :--- | :--- | :--- | :--- |
| **Microphone** | `NSMicrophoneUsageDescription` | Merekam suara saat Push-to-Talk | US-3.1 |
| **Speech Recognition** | `NSSpeechRecognitionUsageDescription` | Mengubah suara menjadi transkrip teks | US-3.1 |
| **Calendars** | `NSCalendarsUsageDescription` | Menulis jadwal meeting ke Apple Calendar | US-3.1 |
| **Reminders** | `NSRemindersUsageDescription` | Menulis alarm pengingat ke Apple Reminders | US-3.1 |
| **Accessibility** | System Settings Prompt | Deteksi posisi notch & focus management | US-1.1 |

### 5.2 Clipboard Secret Masking Standard
* **Rule:** If a secret token is detected (OpenAI `sk-...`, AWS `AKIA...`, GitHub `ghp_...`, JWT), mask characters starting after the 8th character until the 4th character from the end.
* **Example:** `sk-proj-1234567890abcdef1234567890` $\rightarrow$ `sk-proj-12******************7890` (Clearly stated with badge `⚠️ Masked Secret`).

---

## 6. Comprehensive Gherkin BDD Scenarios (Including Failure States)

### 6.1 Happy Path: Voice to Calendar with Offset
```gherkin
Scenario: Sukses mem-parsing perintah suara dengan offset reminder
  Given Jam sistem saat ini 2026-08-18T11:30:00+07:00
  When Pengguna menekan Opt+Space dan berkata "saya ada meeting jam 2 nanti tolong ingatkan 10 menit sebelum itu"
  Then Transkrip lokal menghasilkan "saya ada meeting jam 2 nanti tolong ingatkan 10 menit sebelum itu"
  And Event dibuat di Apple Calendar pada 2026-08-18T14:00:00+07:00
  And Reminder disetel di Apple Reminders pada 2026-08-18T13:50:00+07:00
  And Notch menampilkan badge sukses "Meeting @ 13:50".
```

### 6.2 Edge Case: Jam Sudah Lewat Hari Ini (Past-Time Rollover)
```gherkin
Scenario: Waktu yang disebutkan sudah lewat hari ini
  Given Jam sistem saat ini 2026-08-18T15:00:00+07:00
  When Pengguna mengetik "/remind meeting jam 2" tanpa menyebut kata besok
  Then NLP Engine mendeteksi 14:00 sudah lewat untuk hari ini
  And Sistem otomatis menggeser jadwal ke besok hari 2026-08-19T14:00:00+07:00
  And Notch menampilkan konfirmasi "Disetel untuk Besok, 14:00 (Konfirmasi / Ubah)".
```

### 6.3 Failure State: Izin Microphone Ditolak (Permission Denied)
```gherkin
Scenario: Izin Microphone ditolak oleh pengguna
  Given Izin Microphone berstatus .denied di System Settings
  When Pengguna menekan shortcut Opt+Space
  Then Perekaman audio tidak dijalankan
  And Notch menampilkan alert banner "Izin Mic Dibutuhkan [Buka Pengaturan]"
  And Input bar otomatis beralih ke mode ketik teks.
```

### 6.4 Failure State: Offline Network Fallback
```gherkin
Scenario: Pengguna offline saat menjadwalkan reminder
  Given Koneksi internet terputus (NWPathMonitor status .unsatisfied)
  When Pengguna mengetik "meeting jam 4 sore"
  Then Cloud API dilewati (bypass)
  And Local Regex Parser mengekstrak waktu 16:00:00
  And Jadwal berhasil ditulis secara lokal ke Apple EventKit
  And Notch menampilkan badge "Disimpan Offline: Meeting @ 16:00".
```

---

## 7. Golden Dataset & Evals (10 Comprehensive Suites with Edge Cases)

| ID | Ref Time | Utterance Input | Expected Start Time | Expected Reminder Time | Offset | Edge Case Handling |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **TC-01** | `11:30` | *"meeting jam 2 nanti tolong ingatkan 10 menit sebelum"* | `14:00` (Hari ini) | `13:50` (Hari ini) | 10m | Standar happy path |
| **TC-02** | `15:30` | *"meeting jam 2"* | `14:00` (**Besok**) | `14:00` (**Besok**) | 0m | **Past-time rollover ke besok** |
| **TC-03** | `23:50` | *"20 menit lagi minum vitamin"* | `00:10` (**Besok**) | `00:10` (**Besok**) | 0m | **Midnight date rollover** |
| **TC-04** | `10:00` | *"ingatkan ada sync"* | `null` | `null` | 0m | **Ambiguity check (`is_ambiguous: true`)** |
| **TC-05** | `14:00` | *"besok lusa jam 9 pagi release"* | `+2 days 09:00` | `+2 days 09:00` | 0m | Multi-day relative offset |
| **TC-06** | `08:00` | *"setengah jam lagi call client"* | `08:30` | `08:30` | 0m | Indonesian colloquial "setengah jam" |
| **TC-07** | `12:00` | *"3 jam lagi jemput anak"* | `15:00` | `15:00` | 0m | Relative hour addition |
| **TC-08** | `16:00` | *"jam 5 sore review PR 15 menit sebelumnya alarm"* | `17:00` | `16:45` | 15m | Double time specification (start vs alert) |
| **TC-09** | `11:00` | *"makan siang"* | `12:00` (Inferred) | `12:00` | 0m | Default meal time inference with confidence 0.7 |
| **TC-10** | `13:00` | *"kemarin jam 4"* | `null` | `null` | 0m | **Invalid past date guard rejection** |

---

## 8. Production-Grade API Client (`AIClient.swift`)

```swift
import Foundation

public enum AIClientError: Error, LocalizedError {
    case invalidURL
    case httpError(statusCode: Int, message: String?)
    case decodingError(Error)
    case timeout
    case missingAPIKey

    public var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid API endpoint URL."
        case .httpError(let code, let msg): return "HTTP Error \(code): \(msg ?? "Unknown error")"
        case .decodingError(let err): return "Failed to decode response: \(err.localizedDescription)"
        case .timeout: return "AI service request timed out."
        case .missingAPIKey: return "API key is not configured in Keychain."
        }
    }
}

public final class NotchDeckAIClient: Sendable {
    public static let shared = NotchDeckAIClient()
    private let urlSession: URLSession

    public init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10.0
        config.timeoutIntervalForResource = 15.0
        self.urlSession = URLSession(configuration: config)
    }

    public func parseSchedule(
        userUtterance: String,
        currentDate: Date = Date(),
        apiKey: String
    ) async throws -> NLPScheduleResult {
        guard !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AIClientError.missingAPIKey
        }

        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withTimeZone]
        let currentISO = isoFormatter.string(from: currentDate)

        let systemInstruction = """
        You are the deterministic NLP Scheduling Engine for NotchDeck.
        Parse userUtterance relative to reference_datetime: "\(currentISO)".
        If time has already passed today without a specified date, rollover to tomorrow.
        Output ONLY valid raw JSON matching the schema.
        """

        let prompt = """
        User Utterance: "\(userUtterance)"
        """

        let payload: [String: Any] = [
            "system_instruction": ["parts": [["text": systemInstruction]]],
            "contents": [["parts": [["text": prompt]]]],
            "generationConfig": [
                "temperature": 0.0,
                "responseMimeType": "application/json"
            ]
        ]

        guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=\(apiKey)") else {
            throw AIClientError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await urlSession.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIClientError.httpError(statusCode: -1, message: "Non-HTTP response")
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let errorBody = String(data: data, encoding: .utf8)
            throw AIClientError.httpError(statusCode: httpResponse.statusCode, message: errorBody)
        }

        struct GeminiResponse: Codable {
            struct Candidate: Codable {
                struct Content: Codable {
                    struct Part: Codable { let text: String }
                    let parts: [Part]
                }
                let content: Content
            }
            let candidates: [Candidate]?
        }

        do {
            let geminiRes = try JSONDecoder().decode(GeminiResponse.self, from: data)
            guard let jsonString = geminiRes.candidates?.first?.content.parts.first?.text,
                  let jsonData = jsonString.data(using: .utf8) else {
                throw AIClientError.httpError(statusCode: httpResponse.statusCode, message: "Empty candidate payload")
            }
            return try JSONDecoder().decode(NLPScheduleResult.self, from: jsonData)
        } catch {
            throw AIClientError.decodingError(error)
        }
    }
}
```
