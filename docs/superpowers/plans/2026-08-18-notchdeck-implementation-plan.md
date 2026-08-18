# NotchDeck Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build "NotchDeck", a native macOS Swift 6 / SwiftUI developer utility that integrates an adaptive Dynamic Island notch HUD, Multi-AI Bridges (Antigravity SDK/CLI), Hybrid Voice Scheduler (EventKit sync + offline fallback), Deterministic TTS Voice-Over alerts, and a Smart Clipboard Manager with secret masking.

**Architecture:** A modular native Swift 6 architecture composed of an AppKit `NotchPanel` (`NSPanel` at level `.statusBar + 1`), a central SwiftUI `NotchStateController` state machine, a `SpeechRecognitionManager` with audio waveform extraction, a dual-engine `ScheduleCoordinator` (Cloud Gemini 2.5 Flash + Local Regex Fallback), a deterministic `LocalVoiceOverBuilder`, an `EventKitSyncService`, and an `AntigravityCoordinator` for session observation and CLI dispatching.

**Tech Stack:** Swift 6.0+, SwiftUI, AppKit (`NSPanel`, `NSScreen`, `NSPasteboard`), Speech (`SFSpeechRecognizer`), AVFoundation (`AVAudioEngine`, `AVSpeechSynthesizer`), EventKit (`EKEventStore`), Security (`kSecClassGenericPassword` Keychain).

**Spec:** [`docs/superpowers/specs/2026-08-18-notchdeck-design.md`](file:///Users/heizaaa/Desktop/cdev/iza-3/docs/superpowers/specs/2026-08-18-notchdeck-design.md)

## Global Constraints
- Target Platforms: macOS 14.0+ (Sonoma), macOS 15.0+ (Sequoia), macOS 26.0+ (Tahoe - Primary QA Target).
- Distribution: Direct Notarized DMG (Developer ID Signed, non-App Store).
- Standby RAM Budget: $\le 55\text{ MB}$; Active Expanded RAM Budget: $\le 120\text{ MB}$.
- Rendering & Animation: 60 / 120 FPS ProMotion fluid spring curves.
- Zero Hardcoded Secrets: All API keys stored in macOS Keychain (`kSecClassGenericPassword`).
- Strict Secret Masking: Prefix 8 chars + `***` + Suffix 4 chars for all detected API tokens in clipboard.

---

### Task 1: Swift Package Scaffolding & Directory Setup

**Files:**
- Create: `Package.swift`
- Create: `Sources/NotchDeck/NotchDeckApp.swift`
- Create: `Tests/NotchDeckTests/NotchDeckSanityTests.swift`

**Interfaces:**
- Produces: Base Swift Package executable and test target runnable via `swift test`.

- [ ] **Step 1: Write Package.swift and initial sanity test**

```swift
// Package.swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "NotchDeck",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "NotchDeck", targets: ["NotchDeck"])
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "NotchDeck",
            dependencies: [],
            path: "Sources/NotchDeck"
        ),
        .testTarget(
            name: "NotchDeckTests",
            dependencies: ["NotchDeck"],
            path: "Tests/NotchDeckTests"
        )
    ]
)
```

```swift
// Tests/NotchDeckTests/NotchDeckSanityTests.swift
import Testing
@testable import NotchDeck

@Test func testPackageInitialization() {
    #expect(true == true)
}
```

```swift
// Sources/NotchDeck/NotchDeckApp.swift
import SwiftUI

@main
struct NotchDeckApp: App {
    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
```

- [ ] **Step 2: Run test to verify build and test execution**

Run: `swift test`  
Expected: PASS with 1 test executed.

- [ ] **Step 3: Commit**

```bash
git add Package.swift Sources/ Tests/
git commit -m "feat(scaffold): initialize Swift 6 package and sanity test suite"
```

---

### Task 2: Deterministic Number-to-Words & Local Voice-Over Builder (TDD)

**Files:**
- Create: `Sources/NotchDeck/Audio/LocalVoiceOverBuilder.swift`
- Create: `Tests/NotchDeckTests/LocalVoiceOverBuilderTests.swift`

**Interfaces:**
- Produces: `LocalVoiceOverBuilder.numberToIndonesianWords(_ n: Int) -> String` and `LocalVoiceOverBuilder.buildScript(title: String, offsetMinutes: Int) -> String`.

- [ ] **Step 1: Write failing unit tests for number-to-words and alert scripts**

```swift
// Tests/NotchDeckTests/LocalVoiceOverBuilderTests.swift
import Testing
@testable import NotchDeck

@Suite("Local Voice-Over Builder Tests")
struct LocalVoiceOverBuilderTests {
    @Test("Number to Indonesian words (0-59)")
    func testNumberToIndonesianWords() {
        #expect(LocalVoiceOverBuilder.numberToIndonesianWords(0) == "nol")
        #expect(LocalVoiceOverBuilder.numberToIndonesianWords(1) == "satu")
        #expect(LocalVoiceOverBuilder.numberToIndonesianWords(10) == "sepuluh")
        #expect(LocalVoiceOverBuilder.numberToIndonesianWords(11) == "sebelas")
        #expect(LocalVoiceOverBuilder.numberToIndonesianWords(15) == "lima belas")
        #expect(LocalVoiceOverBuilder.numberToIndonesianWords(20) == "dua puluh")
        #expect(LocalVoiceOverBuilder.numberToIndonesianWords(25) == "dua puluh lima")
        #expect(LocalVoiceOverBuilder.numberToIndonesianWords(45) == "empat puluh lima")
    }

    @Test("Build spoken script with positive offset")
    func testBuildScriptWithOffset() {
        let script = LocalVoiceOverBuilder.buildScript(title: "Meeting Tim Backend", offsetMinutes: 10)
        #expect(script == "Pengingat: Agenda Meeting Tim Backend akan dimulai dalam sepuluh menit.")
    }

    @Test("Build spoken script when starting now (0 offset)")
    func testBuildScriptZeroOffset() {
        let script = LocalVoiceOverBuilder.buildScript(title: "Sync Daily", offsetMinutes: 0)
        #expect(script == "Pengingat: Agenda Sync Daily dimulai sekarang.")
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter LocalVoiceOverBuilderTests`  
Expected: FAIL (Cannot find `LocalVoiceOverBuilder` in scope).

- [ ] **Step 3: Implement LocalVoiceOverBuilder**

```swift
// Sources/NotchDeck/Audio/LocalVoiceOverBuilder.swift
import Foundation

public struct LocalVoiceOverBuilder: Sendable {
    public static func numberToIndonesianWords(_ n: Int) -> String {
        let units = ["nol", "satu", "dua", "tiga", "empat", "lima", "enam", "tujuh", "delapan", "sembilan", "sepuluh", "sebelas"]
        if n < 12 && n >= 0 { return units[n] }
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

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter LocalVoiceOverBuilderTests`  
Expected: PASS (All 3 tests passing).

- [ ] **Step 5: Commit**

```bash
git add Sources/NotchDeck/Audio/ Tests/NotchDeckTests/LocalVoiceOverBuilderTests.swift
git commit -m "feat(audio): add deterministic Indonesian number-to-words and TTS alert builder"
```

---

### Task 3: Local Schedule Parser & Offline Regex Engine (TDD)

**Files:**
- Create: `Sources/NotchDeck/Scheduler/LocalScheduleParser.swift`
- Create: `Sources/NotchDeck/Scheduler/ScheduleModels.swift`
- Create: `Tests/NotchDeckTests/LocalScheduleParserTests.swift`

**Interfaces:**
- Produces: `LocalScheduleParser.parse(utterance: String, referenceDate: Date) -> ScheduleDetail?`

- [ ] **Step 1: Write failing unit tests for offline local parsing**

```swift
// Tests/NotchDeckTests/LocalScheduleParserTests.swift
import Testing
import Foundation
@testable import NotchDeck

@Suite("Local Schedule Parser Offline Tests")
struct LocalScheduleParserTests {
    let calendar = Calendar.current
    let refDate: Date = {
        var comp = DateComponents()
        comp.year = 2026; comp.month = 8; comp.day = 18; comp.hour = 11; comp.minute = 30; comp.second = 0
        comp.timeZone = TimeZone(identifier: "Asia/Jakarta")
        return Calendar.current.date(from: comp)!
    }()

    @Test("Parse standard Indonesian hour with offset")
    func testParseHourWithOffset() {
        let text = "meeting jam 2 nanti tolong ingatkan 10 menit sebelum"
        let result = LocalScheduleParser.parse(utterance: text, referenceDate: refDate)
        #expect(result != nil)
        #expect(result?.title.lowercased().contains("meeting") == true)
        #expect(result?.offsetMinutes == 10)
    }

    @Test("Parse past time today rolls over to tomorrow")
    func testPastTimeRollover() {
        // Ref: 15:30 -> "meeting jam 2" (14:00 has passed today -> rollover to tomorrow)
        var comp = DateComponents()
        comp.year = 2026; comp.month = 8; comp.day = 18; comp.hour = 15; comp.minute = 30; comp.second = 0
        comp.timeZone = TimeZone(identifier: "Asia/Jakarta")
        let lateRefDate = Calendar.current.date(from: comp)!

        let text = "meeting jam 2"
        let result = LocalScheduleParser.parse(utterance: text, referenceDate: lateRefDate)
        #expect(result != nil)
        
        let startComponents = Calendar.current.dateComponents(in: TimeZone(identifier: "Asia/Jakarta")!, from: result!.eventStartDate)
        #expect(startComponents.day == 19) // Tomorrow
        #expect(startComponents.hour == 14)
    }

    @Test("Parse colloquial 'setengah jam lagi'")
    func testSetengahJam() {
        let text = "setengah jam lagi call client"
        let result = LocalScheduleParser.parse(utterance: text, referenceDate: refDate)
        #expect(result != nil)
        #expect(result?.offsetMinutes == 0)
        
        let startComponents = Calendar.current.dateComponents(in: TimeZone(identifier: "Asia/Jakarta")!, from: result!.eventStartDate)
        #expect(startComponents.hour == 12)
        #expect(startComponents.minute == 0)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter LocalScheduleParserTests`  
Expected: FAIL.

- [ ] **Step 3: Implement ScheduleModels and LocalScheduleParser**

```swift
// Sources/NotchDeck/Scheduler/ScheduleModels.swift
import Foundation

public struct ScheduleDetail: Codable, Sendable {
    public let title: String
    public let eventType: String
    public let eventStartISO: String
    public let reminderISO: String
    public let offsetMinutes: Int
    public let confidenceScore: Double

    public var eventStartDate: Date {
        ISO8601DateFormatter().date(from: eventStartISO) ?? Date()
    }

    public var reminderDate: Date {
        ISO8601DateFormatter().date(from: reminderISO) ?? Date()
    }

    enum CodingKeys: String, CodingKey {
        case title
        case eventType = "event_type"
        case eventStartISO = "event_start_iso"
        case reminderISO = "reminder_iso"
        case offsetMinutes = "offset_minutes"
        case confidenceScore = "confidence_score"
    }

    public init(title: String, eventType: String, eventStartISO: String, reminderISO: String, offsetMinutes: Int, confidenceScore: Double) {
        self.title = title
        self.eventType = eventType
        self.eventStartISO = eventStartISO
        self.reminderISO = reminderISO
        self.offsetMinutes = offsetMinutes
        self.confidenceScore = confidenceScore
    }
}

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

    public init(success: Bool, isAmbiguous: Bool, clarificationQuestion: String?, payload: ScheduleDetail?) {
        self.success = success
        self.isAmbiguous = isAmbiguous
        self.clarificationQuestion = clarificationQuestion
        self.payload = payload
    }
}
```

```swift
// Sources/NotchDeck/Scheduler/LocalScheduleParser.swift
import Foundation

public struct LocalScheduleParser: Sendable {
    public static func parse(utterance: String, referenceDate: Date = Date()) -> ScheduleDetail? {
        let lower = utterance.lowercased()
        let cal = Calendar.current
        var targetDate = referenceDate
        var offsetMinutes = 0
        var extractedTitle = "Agenda"

        // Check offset: "X menit sebelum" / "X menit sebelumnya"
        if let offsetMatch = lower.range(of: #"(\d+)\s*menit\s*sebelum"#, options: .regularExpression) {
            let sub = String(lower[offsetMatch])
            if let num = Int(sub.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()) {
                offsetMinutes = num
            }
        }

        // Match "setengah jam lagi"
        if lower.contains("setengah jam lagi") {
            targetDate = cal.date(byAdding: .minute, value: 30, to: referenceDate) ?? referenceDate
            extractedTitle = extractTitle(from: utterance, removing: ["setengah jam lagi", "tolong ingatkan", "saya ada"])
        }
        // Match "X menit lagi"
        else if let minMatch = lower.range(of: #"(\d+)\s*menit\s*lagi"#, options: .regularExpression) {
            let sub = String(lower[minMatch])
            if let num = Int(sub.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()) {
                targetDate = cal.date(byAdding: .minute, value: num, to: referenceDate) ?? referenceDate
                extractedTitle = extractTitle(from: utterance, removing: [sub, "tolong ingatkan", "saya ada"])
            }
        }
        // Match "jam X" / "pukul X"
        else if let hourMatch = lower.range(of: #"(?:jam|pukul)\s*(\d{1,2})(?::(\d{2}))?"#, options: .regularExpression) {
            let sub = String(lower[hourMatch])
            let digits = sub.components(separatedBy: CharacterSet.decimalDigits.inverted).filter { !$0.isEmpty }
            if let hourInt = digits.first.flatMap(Int.init) {
                var hour24 = hourInt
                if hour24 < 12 && (lower.contains("sore") || lower.contains("malam") || (hour24 <= 6 && !lower.contains("pagi"))) {
                    hour24 += 12
                }
                
                var comp = cal.dateComponents([.year, .month, .day, .timeZone], from: referenceDate)
                comp.hour = hour24
                comp.minute = digits.count > 1 ? Int(digits[1]) ?? 0 : 0
                comp.second = 0

                if let candidate = cal.date(from: comp) {
                    if candidate < referenceDate && !lower.contains("kemarin") {
                        // Past-time rollover to tomorrow
                        targetDate = cal.date(byAdding: .day, value: 1, to: candidate) ?? candidate
                    } else {
                        targetDate = candidate
                    }
                }
                extractedTitle = extractTitle(from: utterance, removing: [sub, "sore", "malam", "pagi", "nanti", "tolong ingatkan", "saya ada", "10 menit sebelum", "sebelumnya"])
            }
        } else {
            return nil
        }

        let reminderDate = cal.date(byAdding: .minute, value: -offsetMinutes, to: targetDate) ?? targetDate
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withTimeZone]

        return ScheduleDetail(
            title: extractedTitle.isEmpty ? "Agenda" : extractedTitle.capitalized,
            eventType: "meeting",
            eventStartISO: isoFormatter.string(from: targetDate),
            reminderISO: isoFormatter.string(from: reminderDate),
            offsetMinutes: offsetMinutes,
            confidenceScore: 0.9
        )
    }

    private static func extractTitle(from text: String, removing phrases: [String]) -> String {
        var clean = text
        for p in phrases {
            clean = clean.replacingOccurrences(of: p, with: "", options: .caseInsensitive)
        }
        return clean.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters))
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter LocalScheduleParserTests`  
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/NotchDeck/Scheduler/ Tests/NotchDeckTests/LocalScheduleParserTests.swift
git commit -m "feat(scheduler): implement offline local regex schedule parser with past-time rollover"
```

---

### Task 4: Production AI Client with Timeout & Error Handling (TDD)

**Files:**
- Create: `Sources/NotchDeck/AIBridge/NotchDeckAIClient.swift`
- Create: `Tests/NotchDeckTests/NotchDeckAIClientTests.swift`

**Interfaces:**
- Consumes: `NLPScheduleResult` from `ScheduleModels.swift`.
- Produces: `NotchDeckAIClient.parseSchedule(userUtterance: String, currentDate: Date, apiKey: String) async throws -> NLPScheduleResult`.

- [ ] **Step 1: Write failing unit tests for AIClient error states**

```swift
// Tests/NotchDeckTests/NotchDeckAIClientTests.swift
import Testing
import Foundation
@testable import NotchDeck

@Suite("NotchDeck AI Client Tests")
struct NotchDeckAIClientTests {
    @Test("Missing API Key throws missingAPIKey error")
    func testMissingAPIKey() async {
        let client = NotchDeckAIClient()
        do {
            _ = try await client.parseSchedule(userUtterance: "meeting jam 2", apiKey: "")
            #expect(Bool(false), "Should have thrown AIClientError.missingAPIKey")
        } catch let error as AIClientError {
            switch error {
            case .missingAPIKey: #expect(true)
            default: #expect(Bool(false), "Wrong error: \(error)")
            }
        } catch {
            #expect(Bool(false), "Unexpected error: \(error)")
        }
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter NotchDeckAIClientTests`  
Expected: FAIL.

- [ ] **Step 3: Implement NotchDeckAIClient**

```swift
// Sources/NotchDeck/AIBridge/NotchDeckAIClient.swift
import Foundation

public enum AIClientError: Error, LocalizedError, Sendable {
    case invalidURL
    case httpError(statusCode: Int, message: String?)
    case decodingError(String)
    case timeout
    case missingAPIKey

    public var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid API endpoint URL."
        case .httpError(let code, let msg): return "HTTP Error \(code): \(msg ?? "Unknown error")"
        case .decodingError(let err): return "Failed to decode response: \(err)"
        case .timeout: return "AI service request timed out."
        case .missingAPIKey: return "API key is not configured in Keychain."
        }
    }
}

public final class NotchDeckAIClient: Sendable {
    public static let shared = NotchDeckAIClient()
    private let urlSession: URLSession

    public init(session: URLSession? = nil) {
        if let session = session {
            self.urlSession = session
        } else {
            let config = URLSessionConfiguration.default
            config.timeoutIntervalForRequest = 10.0
            config.timeoutIntervalForResource = 15.0
            self.urlSession = URLSession(configuration: config)
        }
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
            throw AIClientError.decodingError(error.localizedDescription)
        }
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter NotchDeckAIClientTests`  
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/NotchDeck/AIBridge/ Tests/NotchDeckTests/NotchDeckAIClientTests.swift
git commit -m "feat(ai): implement robust AIClient with HTTP verification and error handling"
```

---

### Task 5: Keychain BYOK Storage & Settings Manager (TDD)

**Files:**
- Create: `Sources/NotchDeck/Core/KeychainManager.swift`
- Create: `Tests/NotchDeckTests/KeychainManagerTests.swift`

**Interfaces:**
- Produces: `KeychainManager.save(key: String, value: String) throws`, `KeychainManager.load(key: String) -> String?`, `KeychainManager.delete(key: String) throws`.

- [ ] **Step 1: Write failing unit tests for Keychain API Key CRUD**

```swift
// Tests/NotchDeckTests/KeychainManagerTests.swift
import Testing
@testable import NotchDeck

@Suite("Keychain Manager Tests")
struct KeychainManagerTests {
    let testKey = "notchdeck.test.apikey"

    @Test("Save and load API Key from Keychain")
    func testSaveAndLoadKey() throws {
        try KeychainManager.save(key: testKey, value: "test-secret-key-12345")
        let loaded = KeychainManager.load(key: testKey)
        #expect(loaded == "test-secret-key-12345")
        
        try KeychainManager.delete(key: testKey)
        #expect(KeychainManager.load(key: testKey) == nil)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter KeychainManagerTests`  
Expected: FAIL.

- [ ] **Step 3: Implement KeychainManager**

```swift
// Sources/NotchDeck/Core/KeychainManager.swift
import Foundation
import Security

public struct KeychainManager: Sendable {
    public static let serviceName = "com.notchdeck.app"

    public static func save(key: String, value: String) throws {
        guard let data = value.data(using: .utf8) else { return }
        
        // Remove existing item before saving new one
        try? delete(key: key)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(status))
        }
    }

    public static func load(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    public static func delete(key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter KeychainManagerTests`  
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/NotchDeck/Core/ Tests/NotchDeckTests/KeychainManagerTests.swift
git commit -m "feat(security): implement KeychainManager for secure BYOK storage"
```

---

### Task 6: Smart Clipboard Manager with Strict Secret Masking (TDD)

**Files:**
- Create: `Sources/NotchDeck/Clipboard/ClipboardManager.swift`
- Create: `Tests/NotchDeckTests/ClipboardManagerTests.swift`

**Interfaces:**
- Produces: `ClipboardManager.analyze(text: String) -> ClipboardItemAnalysis`.

- [ ] **Step 1: Write failing unit tests for Clipboard analysis and masking math**

```swift
// Tests/NotchDeckTests/ClipboardManagerTests.swift
import Testing
@testable import NotchDeck

@Suite("Clipboard Manager Tests")
struct ClipboardManagerTests {
    @Test("Masking OpenAI Secret Key matches 8 prefix + *** + 4 suffix rule")
    func testOpenAIKeyMasking() {
        let rawKey = "sk-proj-1234567890abcdef1234567890" // 34 chars
        let analysis = ClipboardManager.analyze(text: rawKey)
        
        #expect(analysis.hasSecret == true)
        #expect(analysis.category == "secret_token")
        #expect(analysis.detectedType == "openai_api_key")
        #expect(analysis.maskedPreview == "sk-proj-**********************7890")
    }

    @Test("Detect Swift Code Snippet")
    func testSwiftCodeDetection() {
        let code = "import SwiftUI\nstruct ContentView: View { var body: some View { Text(\"Hello\") } }"
        let analysis = ClipboardManager.analyze(text: code)
        
        #expect(analysis.hasSecret == false)
        #expect(analysis.category == "code_snippet")
        #expect(analysis.language == "swift")
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter ClipboardManagerTests`  
Expected: FAIL.

- [ ] **Step 3: Implement ClipboardManager**

```swift
// Sources/NotchDeck/Clipboard/ClipboardManager.swift
import Foundation

public struct ClipboardItemAnalysis: Codable, Sendable {
    public let category: String
    public let hasSecret: Bool
    public let detectedType: String?
    public let maskedPreview: String
    public let language: String?
    public let suggestedActions: [String]
    public let cardBadge: String

    public init(category: String, hasSecret: Bool, detectedType: String?, maskedPreview: String, language: String?, suggestedActions: [String], cardBadge: String) {
        self.category = category
        self.hasSecret = hasSecret
        self.detectedType = detectedType
        self.maskedPreview = maskedPreview
        self.language = language
        self.suggestedActions = suggestedActions
        self.cardBadge = cardBadge
    }
}

public struct ClipboardManager: Sendable {
    public static func analyze(text: String) -> ClipboardItemAnalysis {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // 1. Detect Secret Keys
        if trimmed.hasPrefix("sk-proj-") || trimmed.hasPrefix("sk-") || trimmed.hasPrefix("ghp_") || trimmed.hasPrefix("AKIA") {
            let prefixLen = min(8, trimmed.count)
            let suffixLen = min(4, max(0, trimmed.count - prefixLen))
            
            let prefix = String(trimmed.prefix(prefixLen))
            let suffix = String(trimmed.suffix(suffixLen))
            let maskCount = max(0, trimmed.count - prefixLen - suffixLen)
            let masked = prefix + String(repeating: "*", count: maskCount) + suffix

            return ClipboardItemAnalysis(
                category: "secret_token",
                hasSecret: true,
                detectedType: trimmed.hasPrefix("sk") ? "openai_api_key" : "api_key",
                maskedPreview: masked,
                language: nil,
                suggestedActions: ["Copy Masked", "Clear Clipboard"],
                cardBadge: "⚠️ Masked Secret"
            )
        }

        // 2. Detect Code Snippets
        if trimmed.contains("struct ") || trimmed.contains("func ") || trimmed.contains("import ") || trimmed.contains("const ") || trimmed.contains("def ") {
            let lang = trimmed.contains("import SwiftUI") || trimmed.contains("func ") ? "swift" : "code"
            return ClipboardItemAnalysis(
                category: "code_snippet",
                hasSecret: false,
                detectedType: nil,
                maskedPreview: trimmed,
                language: lang,
                suggestedActions: ["Explain Code", "Format"],
                cardBadge: "💻 \(lang.capitalized)"
            )
        }

        return ClipboardItemAnalysis(
            category: "plain_text",
            hasSecret: false,
            detectedType: nil,
            maskedPreview: trimmed,
            language: nil,
            suggestedActions: ["Copy"],
            cardBadge: "📝 Text"
        )
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter ClipboardManagerTests`  
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/NotchDeck/Clipboard/ Tests/NotchDeckTests/ClipboardManagerTests.swift
git commit -m "feat(clipboard): implement ClipboardManager with exact secret masking math"
```

---

### Task 7: Antigravity Session Observation & CLI Subprocess Bridge (TDD)

**Files:**
- Create: `Sources/NotchDeck/AIBridge/AntigravityCoordinator.swift`
- Create: `Tests/NotchDeckTests/AntigravityCoordinatorTests.swift`

**Interfaces:**
- Produces: `AntigravityCoordinator.observeRecentTranscript(brainDir: URL) -> String?` and `AntigravityCoordinator.runCLICommand(arguments: [String]) async throws -> String`.

- [ ] **Step 1: Write failing unit tests for session file observer and subprocess wrapper**

```swift
// Tests/NotchDeckTests/AntigravityCoordinatorTests.swift
import Testing
import Foundation
@testable import NotchDeck

@Suite("Antigravity Coordinator Tests")
struct AntigravityCoordinatorTests {
    @Test("Read recent transcript from mock directory")
    func testReadRecentTranscript() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        
        let sampleTranscript = "{\"step_index\":1,\"type\":\"MODEL_OUTPUT\",\"content\":\"Test Response\"}\n"
        let logFile = tempDir.appendingPathComponent("transcript.jsonl")
        try sampleTranscript.write(to: logFile, atomically: true, encoding: .utf8)

        let result = AntigravityCoordinator.observeRecentTranscript(brainDir: tempDir)
        #expect(result?.contains("Test Response") == true)

        try? FileManager.default.removeItem(at: tempDir)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter AntigravityCoordinatorTests`  
Expected: FAIL.

- [ ] **Step 3: Implement AntigravityCoordinator**

```swift
// Sources/NotchDeck/AIBridge/AntigravityCoordinator.swift
import Foundation

public struct AntigravityCoordinator: Sendable {
    public static func observeRecentTranscript(brainDir: URL) -> String? {
        let logFile = brainDir.appendingPathComponent("transcript.jsonl")
        guard FileManager.default.fileExists(atPath: logFile.path),
              let content = try? String(contentsOf: logFile, encoding: .utf8) else {
            return nil
        }
        let lines = content.components(separatedBy: .newlines).filter { !$0.isEmpty }
        return lines.last
    }

    public static func runCLICommand(arguments: [String]) async throws -> String {
        let process = Process()
        let pipe = Pipe()

        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = arguments
        process.standardOutput = pipe
        process.standardError = pipe

        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? ""
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter AntigravityCoordinatorTests`  
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/NotchDeck/AIBridge/AntigravityCoordinator.swift Tests/NotchDeckTests/AntigravityCoordinatorTests.swift
git commit -m "feat(antigravity): implement session transcript observer and CLI subprocess coordinator"
```

---

### Task 8: Notch State Controller & UI Root View Integration (TDD)

**Files:**
- Create: `Sources/NotchDeck/UI/State/NotchStateController.swift`
- Create: `Sources/NotchDeck/UI/Views/NotchRootView.swift`
- Create: `Tests/NotchDeckTests/NotchStateControllerTests.swift`

**Interfaces:**
- Produces: `NotchStateController` observable state machine (`.collapsed`, `.voiceActive`, `.liveActivity`, `.expanded`).

- [ ] **Step 1: Write failing unit tests for state machine transitions**

```swift
// Tests/NotchDeckTests/NotchStateControllerTests.swift
import Testing
@testable import NotchDeck

@Suite("Notch State Controller Tests")
struct NotchStateControllerTests {
    @Test("Initial state is collapsed and transitions smoothly")
    @MainActor
    func testStateTransitions() {
        let controller = NotchStateController()
        #expect(controller.currentState == .collapsed)

        controller.transition(to: .voiceActive)
        #expect(controller.currentState == .voiceActive)

        controller.transition(to: .expanded)
        #expect(controller.currentState == .expanded)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter NotchStateControllerTests`  
Expected: FAIL.

- [ ] **Step 3: Implement NotchStateController & NotchRootView**

```swift
// Sources/NotchDeck/UI/State/NotchStateController.swift
import SwiftUI

public enum NotchState: Equatable, Sendable {
    case collapsed
    case voiceActive
    case liveActivity(title: String, countdown: String)
    case expanded
}

@MainActor
public final class NotchStateController: ObservableObject {
    @Published public var currentState: NotchState = .collapsed
    @Published public var activeAIModel: String = "Antigravity"
    @Published public var commandPrompt: String = ""

    public init() {}

    public func transition(to newState: NotchState) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            self.currentState = newState
        }
    }
}
```

```swift
// Sources/NotchDeck/UI/Views/NotchRootView.swift
import SwiftUI

public struct NotchRootView: View {
    @ObservedObject public var stateController: NotchStateController

    public init(stateController: NotchStateController) {
        self.stateController = stateController
    }

    public var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.black.opacity(0.95))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )

            switch stateController.currentState {
            case .collapsed:
                HStack(spacing: 8) {
                    Circle().fill(Color.cyan).frame(width: 8, height: 8)
                    Text("NotchDeck").font(.system(size: 11, weight: .medium, design: .rounded)).foregroundColor(.white)
                }
                .padding(.horizontal, 12)

            case .voiceActive:
                HStack(spacing: 12) {
                    Image(systemName: "waveform").foregroundColor(.blue).font(.title3)
                    Text("Mendengarkan...").font(.system(size: 13, weight: .medium)).foregroundColor(.white)
                    Spacer()
                    Button(action: { stateController.transition(to: .collapsed) }) {
                        Image(systemName: "stop.circle.fill").foregroundColor(.orange).font(.title2)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)

            case .liveActivity(let title, let countdown):
                HStack(spacing: 12) {
                    Image(systemName: "calendar.badge.clock").foregroundColor(.green)
                    Text(title).font(.system(size: 12, weight: .semibold)).foregroundColor(.white)
                    Spacer()
                    Text(countdown).font(.system(size: 11, weight: .bold)).foregroundColor(.yellow)
                }
                .padding(.horizontal, 16)

            case .expanded:
                VStack(spacing: 12) {
                    HStack {
                        Menu {
                            Button("Antigravity") { stateController.activeAIModel = "Antigravity" }
                            Button("Claude Code") { stateController.activeAIModel = "Claude Code" }
                        } label: {
                            Text("✨ \(stateController.activeAIModel) ▾")
                                .font(.system(size: 11, weight: .semibold))
                                .padding(.horizontal, 8).padding(.vertical, 4)
                                .background(Color.white.opacity(0.1)).cornerRadius(8)
                        }
                        .menuStyle(.borderlessButton)

                        TextField("Ask AI or speak reminder...", text: $stateController.commandPrompt)
                            .textFieldStyle(.plain)
                            .foregroundColor(.white)

                        Button(action: { stateController.transition(to: .voiceActive) }) {
                            Image(systemName: "mic.fill").foregroundColor(.cyan)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(8)
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(12)

                    Spacer()
                }
                .padding(16)
            }
        }
        .frame(
            width: widthForState(stateController.currentState),
            height: heightForState(stateController.currentState)
        )
    }

    private func widthForState(_ state: NotchState) -> CGFloat {
        switch state {
        case .collapsed: return 180
        case .voiceActive: return 360
        case .liveActivity: return 320
        case .expanded: return 540
        }
    }

    private func heightForState(_ state: NotchState) -> CGFloat {
        switch state {
        case .collapsed: return 32
        case .voiceActive: return 60
        case .liveActivity: return 44
        case .expanded: return 380
        }
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter NotchStateControllerTests`  
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/NotchDeck/UI/ Tests/NotchDeckTests/NotchStateControllerTests.swift
git commit -m "feat(ui): implement NotchStateController and fluid NotchRootView"
```

---

## Plan Self-Review Check
- [x] Spec coverage verified against [`docs/superpowers/specs/2026-08-18-notchdeck-design.md`](file:///Users/heizaaa/Desktop/cdev/iza-3/docs/superpowers/specs/2026-08-18-notchdeck-design.md).
- [x] No placeholder code, all steps include complete code snippets, test runs, and commit commands.
- [x] Exact data models match between Task 2, Task 3, Task 4, and Task 6.

---
