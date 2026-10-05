import Foundation
import NaturalLanguage

// Minimal reproduction of TaskIngressGateway and TaskEgressValidator methods for testing
class TestIngressGateway {
    public static func resolveLanguage(prompt: String, modelDetected: String? = nil) -> String {
        if let detected = modelDetected?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
           !detected.isEmpty, detected != "unspecified" {
            return detected
        }
        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return Locale.current.language.languageCode?.identifier ?? "id"
        }
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(trimmed)
        if let dominant = recognizer.dominantLanguage?.rawValue, !dominant.isEmpty {
            return dominant
        }
        return "id"
    }

    public static func fallbackDeconstruct(userPrompt: String, connectedApps: [String]) -> (app: String, intent: String, entity: String, targetIdx: Int?, goal: String) {
        let lower = userPrompt.lowercased()
        let matchedApp = connectedApps.first { lower.contains($0.lowercased()) }
        let candidateApp = matchedApp ?? connectedApps.first ?? "Workspace"
        let requiresCUA = (candidateApp != "None" && !connectedApps.isEmpty)

        return (
            app: requiresCUA ? candidateApp : "None",
            intent: requiresCUA ? "interact" : "conversational",
            entity: requiresCUA ? "main_window" : "user",
            targetIdx: nil,
            goal: userPrompt
        )
    }
}

class TestEgressValidator {
    public static func getLanguageName(lang: String) -> String {
        return Locale(identifier: "en").localizedString(forLanguageCode: lang) ?? lang
    }

    public static func formatFinding(extractedData: String, targetIndex: Int?) -> String {
        if !extractedData.isEmpty && extractedData.lowercased() != "none" {
            return extractedData
        } else if let targetIdx = targetIndex {
            return "Item #\(targetIdx) telah diperiksa."
        } else {
            return "Pemeriksaan selesai."
        }
    }
}

var passed = 0
var failed = 0

func assertTest(_ condition: Bool, _ name: String) {
    if condition {
        print("✅ PASS: \(name)")
        passed += 1
    } else {
        print("❌ FAIL: \(name)")
        failed += 1
    }
}

print("=== Running TDD Test Suite: Task I (Zero Hardcoding & Language Resolution) ===")

// 1. Natural Language resolution for Indonesian
let id1 = TestIngressGateway.resolveLanguage(prompt: "buka email saya")
assertTest(id1 == "id", "Resolves Indonesian 'buka email saya' -> id (got \(id1))")

let id2 = TestIngressGateway.resolveLanguage(prompt: "cek kotak masuk dan cari dokumen ini")
assertTest(id2 == "id", "Resolves Indonesian 'cek kotak masuk...' -> id (got \(id2))")

// 2. Natural Language resolution for English
let en1 = TestIngressGateway.resolveLanguage(prompt: "open my inbox and read the email")
assertTest(en1 == "en", "Resolves English 'open my inbox...' -> en (got \(en1))")

let en2 = TestIngressGateway.resolveLanguage(prompt: "check the third message on the screen")
assertTest(en2 == "en", "Resolves English 'check the third message...' -> en (got \(en2))")

// 3. Natural Language resolution for French / Other languages
let fr1 = TestIngressGateway.resolveLanguage(prompt: "bonjour s'il vous plaît ouvrez mon courrier")
assertTest(fr1 == "fr", "Resolves French 'bonjour...' -> fr (got \(fr1))")

// 4. Model override precedence
let override1 = TestIngressGateway.resolveLanguage(prompt: "test", modelDetected: "ja")
assertTest(override1 == "ja", "Model detected code overrides when valid (got \(override1))")

// 5. Ingress fallback is completely abstract (Zero inbox_item_1 assumption)
let fallbackRes = TestIngressGateway.fallbackDeconstruct(
    userPrompt: "kirim catatan penting ke tim finance",
    connectedApps: ["Mail", "Notes"]
)
assertTest(fallbackRes.intent == "interact", "Fallback intent is abstract 'interact', not hardcoded 'inspect'")
assertTest(fallbackRes.entity == "main_window", "Fallback entity is abstract 'main_window', not hardcoded 'inbox_item_1'")
assertTest(fallbackRes.targetIdx == nil, "Fallback target index is nil, not rigidly forced to 1")
assertTest(fallbackRes.goal == "kirim catatan penting ke tim finance", "Fallback goal preserves original user prompt faithfully")

// 6. Egress Validator Locale language naming
let idName = TestEgressValidator.getLanguageName(lang: "id")
assertTest(idName.lowercased().contains("indonesian"), "Locale resolves 'id' -> 'Indonesian' (got \(idName))")

let enName = TestEgressValidator.getLanguageName(lang: "en")
assertTest(enName.lowercased().contains("english"), "Locale resolves 'en' -> 'English' (got \(enName))")

let jaName = TestEgressValidator.getLanguageName(lang: "ja")
assertTest(jaName.lowercased().contains("japanese"), "Locale resolves 'ja' -> 'Japanese' (got \(jaName))")

// 7. Egress factual extraction presentation (Zero ordinals like 'pertama')
let fact1 = TestEgressValidator.formatFinding(extractedData: "Pengirim: Alice, Subjek: Agenda", targetIndex: 3)
assertTest(fact1 == "Pengirim: Alice, Subjek: Agenda", "Factual extraction presented directly without template wrapper")

let fact2 = TestEgressValidator.formatFinding(extractedData: "", targetIndex: 4)
assertTest(fact2.contains("#4") && !fact2.contains("keempat"), "Fallback with index uses dynamic '#4', not static ordinal 'keempat'")

// 8. Static Code Invariant Checks (Zero Hardcoding in Source Files)
let repoRoot = "/Users/heizaaa/Desktop/cdev/iza-3"
let ingressFile = repoRoot + "/boringNotch/Clicky/Reasoning/Ingress/TaskIngressGateway.swift"
let egressFile = repoRoot + "/boringNotch/Clicky/Reasoning/Validator/TaskEgressValidator.swift"
let vmLoopFile = repoRoot + "/boringNotch/Clicky/CUA/Loop/CompanionVMAgentLoop.swift"
let watcherFile = repoRoot + "/boringNotch/Clicky/CUA/Loop/CompanionVMBackgroundWatcher.swift"

if let ingressContent = try? String(contentsOfFile: ingressFile, encoding: .utf8) {
    assertTest(!ingressContent.contains("'saya', 'yang'"), "TaskIngressGateway has no injected Indonesian word lists in prompt")
} else {
    assertTest(false, "Failed to read TaskIngressGateway.swift")
}

if let vmContent = try? String(contentsOfFile: vmLoopFile, encoding: .utf8) {
    assertTest(!vmContent.contains("userLang == \"id\""), "CompanionVMAgentLoop has zero binary 'userLang == \"id\"' ternaries")
} else {
    assertTest(false, "Failed to read CompanionVMAgentLoop.swift")
}

if let egressContent = try? String(contentsOfFile: egressFile, encoding: .utf8) {
    assertTest(egressContent.contains("func synthesizeNotice"), "TaskEgressValidator provides dynamic universal synthesizeNotice method")
} else {
    assertTest(false, "Failed to read TaskEgressValidator.swift")
}

if let watcherContent = try? String(contentsOfFile: watcherFile, encoding: .utf8) {
    assertTest(!watcherContent.contains("Ada email penting yang baru masuk"), "CompanionVMBackgroundWatcher has no hardcoded static alert text")
} else {
    assertTest(false, "Failed to read CompanionVMBackgroundWatcher.swift")
}

print("=== Summary: \(passed) passed, \(failed) failed ===")
exit(failed == 0 ? 0 : 1)
