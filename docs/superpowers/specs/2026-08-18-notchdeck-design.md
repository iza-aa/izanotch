# 📄 NOTCHDECK MASTER SPECIFICATION & ARCHITECTURE DESIGN DOCUMENT
**App Name:** NotchDeck (macOS Dynamic Island & Developer Command Center)  
**Target Platform:** macOS 14.0+ (Sonoma), macOS 15.0+ (Sequoia), macOS 26.0+ (Tahoe - Primary QA Target)  
**Distribution Model:** Direct Notarized DMG (Apple Developer ID signed, Non-App Store)  
**Date:** 2026-08-18  
**Status:** CANONICAL SINGLE SOURCE OF TRUTH (VALIDATED & APPROVED)  

---

## 1. Executive Summary & UI Reference Mapping

NotchDeck is a native macOS developer utility built with **Swift 6, SwiftUI, and AppKit**. It transforms the MacBook notch (and floating space on external displays) into an active **Developer Command Center & Dynamic Island HUD**.

```
┌──────────────────────────────────────────────────────────────────────────┐
│                             MacBook Notch                                │
├──────────────────────────────────────────────────────────────────────────┤
│  [✨ Antigravity ▾]  [ 🔍 Universal Command & Prompt Bar... ]  [🎙️ Mic] │  <- Header (Images 1 & 2)
├──────────────────────────────────────────────────────────────────────────┤
│  [ History 24 ]  [ Prompts 12 ]  [ Schedule 3 ]  [ Clipboard ]  [ + ]    │  <- Filter Pills (Image 1)
├──────────────────────────────────────────────────────────────────────────┤
│  ┌─────────────────────────┐  ┌────────────────────────────────────────┐ │
│  │ 🤖 Active AI Stream     │  │ 🎙️ Voice Waveform & Transcript        │ │  <- Dynamic Cards
│  │ (Claude / Antigravity)  │  │ "Saya ada meeting jam 2..." (Image 4)  │ │     (Images 2 & 4)
│  └─────────────────────────┘  └────────────────────────────────────────┘ │
│  ┌─────────────────────────────────────────────────────────────────────┐ │
│  │ 📋 Clipboard Cards with Secret Masking & Drag Dropzone (Image 1)    │ │
│  └─────────────────────────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────────────────────┘
```

### Visual Reference Mapping (from Uploaded Designs)
1. **Header & Carousel Deck (Image 1 - Supaste Style):** Curved ear integration into menu bar, universal search bar, filter pills (`History`, `Prompts`, `Schedule`, `Clipboard`), and horizontal card carousel.
2. **AI Card & Model Switcher (Image 2 - Claude/Sonnet Card):** Model dropdown selector (`Antigravity ▾`, `Claude Code ▾`, `Codex ▾`), streaming response preview, action dock (`Copy`, `Send to Editor`).
3. **Dynamic Island Live Activities (Images 3 & 5):** Compact pills showing status dots, meeting countdown (`10m to Meeting`), and task progress scrubber.
4. **Push-to-Talk Waveform HUD (Image 4):** Compact black capsule displaying blue audio waveform (`||||||`), live streaming speech-to-text transcript, Stop button, and quick-action chips.

---

## 2. Hardware Notch & Windowing Engine (EPIC 1)

### 2.1 Windowing Architecture
* **Class:** `NotchPanel: NSPanel`
* **Window Level:** `.statusBar + 1` (floats above fullscreen windows and across all spaces)
* **Collection Behaviors:** `[.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]`
* **Style Mask:** `[.borderless, .nonactivatingPanel]`
* **Hardware Detection:** Reads `NSScreen.main?.auxiliaryTopLeftArea` and `safeAreaInsets.top`.
  * *MacBook Notch:* Anchors precisely under physical notch with curved ears.
  * *External Monitor:* Renders as a floating pill with `24px` corner radius positioned `10px` below the top screen edge.

### 2.2 Visual State Machine & Resource Budget
* **`.collapsed` (Standby):** $180\text{px} \times 32\text{px}$. Standby pill with status dots. **RAM budget $\le 55\text{ MB}$**.
* **`.voiceActive` (Push-to-Talk):** $360\text{px} \times 70\text{px}$. Audio waveform + live transcript stream + Stop button.
* **`.liveActivity` (Compact HUD):** $320\text{px} \times 44\text{px}$. Countdown badge, task progress bar.
* **`.expanded` (Full Command Center):** $640\text{px} \times 460\text{px}$. Command bar, filter pills, card carousel. **Active RAM budget $\le 120\text{ MB}$**.
* **Frame Rate Target:** Locked at **60 FPS / 120 FPS ProMotion** with SwiftUI spring animations.

---

## 3. Multi-AI Bridge & Dispatcher Architecture (EPIC 2)

### 3.1 Strategy & Adapter Pattern
NotchDeck integrates with desktop developer AI tools via official CLIs, SDKs, and local session watchers rather than fragile GUI injection:

```
┌────────────────────────────────────────────────────────────┐
│                  NotchDeck AI Coordinator                  │
├─────────────────────────────┬──────────────────────────────┤
│ 1. Antigravity Adapter      │ 2. Claude Code CLI Adapter   │
│ - Local Transcript Watcher  │ - Headless Subprocess Exec   │
│ - Official SDK / CLI Runner │   (`claude --print ...`)     │
│ - (Phase 1 Spike Target)    │ - Apple Events fallback      │
├─────────────────────────────┴──────────────────────────────┤
│ 3. Codex CLI Adapter                                       │
│ - Subprocess Runner (stdin / stdout stream)                │
└────────────────────────────────────────────────────────────┘
```

### 3.2 Phased Roadmap
* **Phase 1 (MVP Spike):** Antigravity CLI/SDK Integration + Local Session Watcher spike (verify `~/.gemini/antigravity/brain/` session stability).
* **Phase 2:** Claude Code CLI headless execution integration (`claude` binary bridge).
* **Phase 3:** Codex CLI integration.

---

## 4. Hybrid Voice, Smart Scheduler & Deterministic Audio Engine (EPIC 3 & 4)

### 4.1 Speech-to-Text (`SFSpeechRecognizer`)
* Uses `SFSpeechRecognizer(locale: Locale(identifier: "id-ID"))`.
* **Runtime Verification:** Checks `recognizer.supportsOnDeviceRecognition`. If false or language pack not installed in macOS System Settings, automatically switches to Apple online dictation or displays an actionable prompt to download the offline Indonesian language pack.

### 4.2 Dual-Engine Schedule Parsing
1. **Primary (Online):** Cloud API (`Gemini 2.5 Flash`) with strict $1.5\text{s}$ timeout.
2. **Fallback (Offline / Timeout):** Native Swift `LocalScheduleParser` using regex rules and `NSDataDetector`.
   * **Mandatory Offline Coverage:** Standard hours ("jam X", "pukul X"), relative minutes ("X menit lagi"), relative hours ("X jam lagi"), colloquial Indonesian ("setengah jam lagi", "besok jam X", "lusa jam X", "makan siang").

### 4.3 Deterministic Offline Voice-Over Generator (Zero LLM Dependency)
Spoken alerts are built locally in Swift to guarantee **0 ms network lag** and **100% offline reliability** using a general Indonesian number-to-words algorithm (0–59 minutes):

```swift
import Foundation

public struct LocalVoiceOverBuilder {
    public static func numberToIndonesianWords(_ n: Int) -> String {
        let units = ["nol", "satu", "dua", "tiga", "empat", "lima", "enam", "tujuh", "delapan", "sembilan", "sepuluh", "sebelas"]
        if n < 12 { return units[n] }
        if n < 20 { return "\(units[n - 10]) belas" }
        if n < 100 {
            let tens = n / 10
            let rem = n % 10
            return rem == 0 ? "\(units[tens]) puluh" : "\(units[tens]) puluh \(units[rem])"
        }
        return "\(n)"
    }

    public static func buildScript(title: String, offsetMinutes: Int) -> String {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if offsetMinutes <= 0 {
            return "Pengingat: Agenda \(cleanTitle) dimulai sekarang."
        } else {
            let offsetWords = numberToIndonesianWords(offsetMinutes)
            return "Pengingat: Agenda \(cleanTitle) akan dimulai dalam \(offsetWords) menit."
        }
    }
}
```

---

## 5. Security, Secrets & macOS Permissions Matrix

### 5.1 Permissions Matrix
| Permission | Info.plist Key | Purpose & User Prompt Description | Required For |
| :--- | :--- | :--- | :--- |
| **Microphone** | `NSMicrophoneUsageDescription` | "NotchDeck requires microphone access for Push-to-Talk voice scheduling." | US-3.1 |
| **Speech Recognition** | `NSSpeechRecognitionUsageDescription` | "NotchDeck needs speech recognition to transcribe your spoken voice into text." | US-3.1 |
| **Calendars** | `NSCalendarsUsageDescription` | "NotchDeck adds scheduled meetings to your Apple Calendar." | US-3.1 |
| **Reminders** | `NSRemindersUsageDescription` | "NotchDeck creates alerts in Apple Reminders." | US-3.1 |
| **Accessibility** | System Settings Prompt | "Required for global Push-to-Talk hotkey (⌥ Space) and active window awareness." | US-1.1 & US-3.1 |

### 5.2 Clipboard Secret Masking Standard
* **Rule:** If a secret token is detected (OpenAI `sk-proj-...`, GitHub `ghp_...`, AWS `AKIA...`, JWT), mask characters starting immediately after the provider prefix (first 8 characters) until the last 4 characters.
* **Math Proof:**
  * Input: `sk-proj-1234567890abcdef1234567890` (34 characters)
  * Prefix (Chars 1–8): `sk-proj-`
  * Suffix (Chars 31–34): `7890`
  * Masked Segment (Chars 9–30): `**********************` (22 asterisks)
  * Output: `sk-proj-**********************7890` (Badge: `⚠️ Masked Secret`)

---

## 6. Complete INVEST Backlog & User Stories

```
EPIC 1: Hardware Notch Dynamic Windowing Engine
├── US-1.1: Hardware Notch Detection & Adaptive Floating Panel
└── US-1.2: Interactive Spring Animation & State Controller

EPIC 2: Multi-AI Command Deck & CLI Bridge
├── US-2.1: Universal Prompt Dispatcher (Antigravity & Claude Code CLI)
├── US-2.2: Phase 1 Spike - Antigravity SDK/Session Investigation
└── US-2.3: BYOK Onboarding & Keychain Settings Manager

EPIC 3: Hybrid Voice & Smart NLP Scheduler
├── US-3.1: Push-to-Talk Speech-to-Text HUD (Offline SFSpeechRecognizer)
├── US-3.2: Dual-Engine NLP Scheduler (Cloud Gemini 2.5 + Local Fallback)
└── US-3.3: Two-Way Sync with Apple EventKit (Calendar & Reminders)

EPIC 4: Deterministic Verbal Voice-Over Engine
└── US-4.1: Offline Spoken TTS Alert Engine (AVSpeechSynthesizer)

EPIC 5: Developer Utilities (Clipboard & Dropzone Hub)
├── US-5.1: Clipboard History with Strict Secret Masking & Carousel
└── US-5.2: Notch Drag-and-Drop Staging Zone
```

### Key User Story: US-2.3 (BYOK Onboarding & Keychain Settings)
* **As a:** Developer yang pertama kali memakai NotchDeck.
* **I want to:** Memasukkan Gemini/Anthropic API Key saya di menu Settings dengan tombol "Test Connection".
* **So that:** Kunci API saya tersimpan aman di macOS Keychain dan saya siap menggunakan fitur AI cloud.

---

## 7. Comprehensive Gherkin BDD Scenarios (Including Failure States)

### 7.1 Happy Path: Voice to Calendar with Offset
```gherkin
Scenario: Sukses mem-parsing perintah suara dengan offset reminder
  Given Jam sistem saat ini 2026-08-18T11:30:00+07:00
  When Pengguna menekan Opt+Space dan berkata "saya ada meeting jam 2 nanti tolong ingatkan 10 menit sebelum itu"
  Then Transkrip lokal menghasilkan "saya ada meeting jam 2 nanti tolong ingatkan 10 menit sebelum itu"
  And Event dibuat di Apple Calendar pada 2026-08-18T14:00:00+07:00
  And Reminder disetel di Apple Reminders pada 2026-08-18T13:50:00+07:00
  And Notch menampilkan badge sukses "Meeting @ 13:50".
```

### 7.2 Edge Case: Past-Time Rollover (Jam Sudah Lewat Hari Ini)
```gherkin
Scenario: Waktu yang disebutkan sudah lewat hari ini
  Given Jam sistem saat ini 2026-08-18T15:00:00+07:00
  When Pengguna mengetik "/remind meeting jam 2" tanpa menyebut kata besok
  Then NLP Engine mendeteksi 14:00 sudah lewat untuk hari ini
  And Sistem otomatis menggeser jadwal ke besok hari 2026-08-19T14:00:00+07:00
  And Notch menampilkan konfirmasi "Disetel untuk Besok, 14:00 (Konfirmasi / Ubah)".
```

### 7.3 Failure State: Izin Microphone Ditolak
```gherkin
Scenario: Izin Microphone ditolak oleh pengguna
  Given Izin Microphone berstatus .denied di System Settings
  When Pengguna menekan shortcut Opt+Space
  Then Perekaman audio dibatalkan secara aman
  And Notch menampilkan alert banner "Izin Mic Dibutuhkan [Buka Pengaturan]"
  And Input bar otomatis beralih ke mode ketik teks.
```

### 7.4 Failure State: Offline Network Fallback
```gherkin
Scenario: Pengguna offline saat menjadwalkan reminder
  Given Koneksi internet terputus (NWPathMonitor status .unsatisfied)
  When Pengguna mengetik "meeting jam 4 sore"
  Then Cloud API di-bypass
  And Local Schedule Parser mengekstrak waktu 16:00:00
  And Jadwal berhasil ditulis secara lokal ke Apple EventKit
  And Notch menampilkan badge "Disimpan Offline: Meeting @ 16:00".
```

### 7.5 Failure State: Target CLI / App Integration Fails Gracefully
```gherkin
Scenario: Claude Code CLI binary tidak ditemukan pada PATH
  Given Binary `claude` belum terpasang di sistem pengguna
  When Pengguna memilih model "Claude Code" dan mengirim prompt
  Then Notch menangkap error non-zero exit code
  And Notch menampilkan notifikasi banner yang jelas "Claude CLI tidak ditemukan [Petunjuk Instalasi]"
  And Aplikasi tidak mengalami crash atau silent failure.
```

---

## 8. System Prompts & Structured JSON Schemas

### 8.1 `NLP_SCHEDULE_REMINDER_PARSER`
```text
You are the high-speed deterministic NLP Scheduling Engine for NotchDeck.
Parse raw natural language (Indonesian/English) relative to `reference_datetime`.
If the time has already passed today without an explicit date, rollover to tomorrow.
If ambiguous or missing time, return "is_ambiguous": true with a concise "clarification_question" in Indonesian.
Output MUST be raw valid JSON matching the schema.
```

#### JSON Schema
```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "type": "object",
  "required": ["success", "is_ambiguous", "clarification_question", "payload"],
  "properties": {
    "success": { "type": "boolean" },
    "is_ambiguous": { "type": "boolean" },
    "clarification_question": { "type": ["string", "null"] },
    "payload": {
      "type": ["object", "null"],
      "required": ["title", "event_type", "event_start_iso", "reminder_iso", "offset_minutes", "confidence_score"],
      "properties": {
        "title": { "type": "string", "maxLength": 40 },
        "event_type": { "type": "string", "enum": ["meeting", "task", "break", "deadline", "call", "custom"] },
        "event_start_iso": { "type": "string", "format": "date-time" },
        "reminder_iso": { "type": "string", "format": "date-time" },
        "offset_minutes": { "type": "integer", "minimum": 0 },
        "confidence_score": { "type": "number", "minimum": 0.0, "maximum": 1.0 }
      }
    }
  }
}
```

### 8.2 `SMART_CLIPBOARD_INSPECTOR`
```text
You are the Smart Clipboard Security & Developer Classification Engine for NotchDeck.
Analyze copied strings from NSPasteboard: detect secret tokens (OpenAI, AWS, GitHub, JWT), classify code languages, and generate safe masked strings.
Output MUST be raw valid JSON.
```

#### JSON Schema
```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "type": "object",
  "required": ["category", "has_secret", "detected_type", "masked_preview", "language", "suggested_actions", "card_badge"],
  "properties": {
    "category": { "type": "string", "enum": ["secret_token", "code_snippet", "url", "plain_text", "color_hex"] },
    "has_secret": { "type": "boolean" },
    "detected_type": { "type": ["string", "null"] },
    "masked_preview": { "type": "string" },
    "language": { "type": ["string", "null"] },
    "suggested_actions": { "type": "array", "items": { "type": "string" } },
    "card_badge": { "type": "string" }
  }
}
```

---

## 9. Golden Dataset & Evals (10 Comprehensive Suites)

| ID | Ref Time | Utterance Input | Expected Start Time | Expected Reminder Time | Offset | Offline Fallback Capable |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **TC-01** | `11:30` | *"meeting jam 2 nanti tolong ingatkan 10 menit sebelum"* | `14:00` (Today) | `13:50` (Today) | 10m | YES (Regex) |
| **TC-02** | `15:30` | *"meeting jam 2"* | `14:00` (**Tomorrow**) | `14:00` (**Tomorrow**) | 0m | YES (Rollover) |
| **TC-03** | `23:50` | *"20 menit lagi minum vitamin"* | `00:10` (**Tomorrow**) | `00:10` (**Tomorrow**) | 0m | YES (Midnight) |
| **TC-04** | `10:00` | *"ingatkan ada sync"* | `null` | `null` | 0m | YES (`is_ambiguous`) |
| **TC-05** | `14:00` | *"lusa jam 9 pagi release"* | `+2 days 09:00` | `+2 days 09:00` | 0m | YES (Relative days) |
| **TC-06** | `08:00` | *"setengah jam lagi call client"* | `08:30` | `08:30` | 0m | YES ("setengah jam") |
| **TC-07** | `12:00` | *"3 jam lagi jemput anak"* | `15:00` | `15:00` | 0m | YES (Relative hours) |
| **TC-08** | `16:00` | *"jam 5 sore review PR 15 menit sebelumnya alarm"* | `17:00` | `16:45` | 15m | YES (Start + Alert) |
| **TC-09** | `11:00` | *"makan siang"* | `12:00` (Inferred) | `12:00` | 0m | YES (Meal rule, conf: 0.7) |
| **TC-10** | `13:00` | *"kemarin jam 4"* | `null` | `null` | 0m | YES (Invalid past rejection) |

---

## 10. Production-Grade Swift Architecture Code

```swift
import Foundation

// MARK: - Codable Data Models
public struct NLPScheduleResult: Codable, Sendable {
    public let success: Bool
    public let isAmbiguous: Bool
    public let clarificationQuestion: String?
    public let payload: ScheduleDetail?

    enum CodingKeys: String, CodingKey {
        case success
        case isAmbiguous = "is_ambiguous"
        case clarificationQuestion = "clarification_question"
        case payload
    }
}

public struct ScheduleDetail: Codable, Sendable {
    public let title: String
    public let eventType: String
    public let eventStartISO: String
    public let reminderISO: String
    public let offsetMinutes: Int
    public let confidenceScore: Double

    enum CodingKeys: String, CodingKey {
        case title
        case eventType = "event_type"
        case eventStartISO = "event_start_iso"
        case reminderISO = "reminder_iso"
        case offsetMinutes = "offset_minutes"
        case confidenceScore = "confidence_score"
    }
}

// MARK: - Error Types
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

// MARK: - Production API Client
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

        let prompt = "User Utterance: \"\(userUtterance)\""

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
