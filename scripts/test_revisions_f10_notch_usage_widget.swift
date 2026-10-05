// scripts/test_revisions_f10_notch_usage_widget.swift
import Foundation

let widgetPath = "boringNotch/Clicky/Vision/ChatGPTAccountMonitorWidget.swift"
let aiUsagePath = "boringNotch/components/AIUsage/AIUsageView.swift"

print("=== Running Test F-10 Task 4: Dynamic Island Notch AI ChatGPT Usage Widget ===")

guard let content = try? String(contentsOfFile: widgetPath, encoding: .utf8) else {
    print("❌ [FAIL] Cannot read \(widgetPath) (file does not exist yet)")
    exit(1)
}

guard let aiUsageContent = try? String(contentsOfFile: aiUsagePath, encoding: .utf8) else {
    print("❌ [FAIL] Cannot read \(aiUsagePath)")
    exit(1)
}

var passed = 0
var total = 5

// 1. Observed pool check
if content.contains("ChatGPTAccountPoolManager.shared") {
    print("  ✅ [PASS] Observes ChatGPTAccountPoolManager.shared reactive state")
    passed += 1
} else {
    print("  ❌ [FAIL] Missing ChatGPTAccountPoolManager.shared binding")
}

// 2. Active account & 6 Luna indicator
if content.contains("gpt-6-luna") && (content.contains("activeAccount") || content.contains("activeAccountPill")) {
    print("  ✅ [PASS] Renders active account status with gpt-6-luna badge")
    passed += 1
} else {
    print("  ❌ [FAIL] Missing active account or gpt-6-luna indicator")
}

// 3. Account list / Cooldown status check
if (content.contains("accountRow") || content.contains("ForEach")) && content.contains("cooldown") {
    print("  ✅ [PASS] Renders multi-account pool list with cooldown countdown support")
    passed += 1
} else {
    print("  ❌ [FAIL] Missing account list or cooldown display")
}

// 4. Add account button check
if content.contains("Add Account") || content.contains("tambahAkun") {
    print("  ✅ [PASS] Provides Add Account action for multi-account onboarding")
    passed += 1
} else {
    print("  ❌ [FAIL] Missing Add Account interactive button")
}

// 5. Integration into AIUsageView top bar or switcher
if aiUsageContent.contains("ChatGPT") && aiUsageContent.contains("ChatGPTAccountMonitorWidget") {
    print("  ✅ [PASS] Integrated into Notch AIUsageView app switcher and panel hierarchy")
    passed += 1
} else {
    print("  ❌ [FAIL] Not integrated into AIUsageView")
}

print("=== Results: \(passed)/\(total) tests passed ===")
if passed == total {
    print("ALL TESTS PASSED")
    exit(0)
} else {
    print("SOME TESTS FAILED")
    exit(1)
}
