// scripts/test_revisions_f10_codex_vision_service.swift
import Foundation

let servicePath = "boringNotch/Clicky/Vision/ChatGPTCodexVisionService.swift"
print("=== Running Test F-10 Task 2: Headless 6 Luna Medium Vision Service ===")

guard let content = try? String(contentsOfFile: servicePath, encoding: .utf8) else {
    print("❌ [FAIL] Cannot read \(servicePath) (file does not exist yet)")
    exit(1)
}

var passed = 0
var total = 5

// 1. Binary path check
if content.contains("/Applications/ChatGPT.app/Contents/Resources/codex") {
    print("  ✅ [PASS] References official ChatGPT Codex binary path")
    passed += 1
} else {
    print("  ❌ [FAIL] Missing official ChatGPT Codex binary path")
}

// 2. Model check
if content.contains("gpt-6-luna") {
    print("  ✅ [PASS] Configured for 6 Luna (gpt-6-luna) model")
    passed += 1
} else {
    print("  ❌ [FAIL] Missing gpt-6-luna model definition")
}

// 3. Reasoning effort check
if content.contains("reasoning_effort=medium") {
    print("  ✅ [PASS] Enforces medium reasoning effort (reasoning_effort=medium)")
    passed += 1
} else {
    print("  ❌ [FAIL] Missing reasoning_effort=medium parameter")
}

// 4. CODEX_HOME environment injection check
if content.contains("CODEX_HOME") {
    print("  ✅ [PASS] Injects CODEX_HOME for isolated per-process account switching")
    passed += 1
} else {
    print("  ❌ [FAIL] Missing CODEX_HOME environment handling")
}

// 5. Vision coordinate parser check
if content.contains("VisionCoordinateResult") && content.contains("confidence") {
    print("  ✅ [PASS] Declares VisionCoordinateResult data model with confidence metric")
    passed += 1
} else {
    print("  ❌ [FAIL] Missing VisionCoordinateResult structure")
}

print("=== Results: \(passed)/\(total) tests passed ===")
if passed == total {
    print("ALL TESTS PASSED")
    exit(0)
} else {
    print("SOME TESTS FAILED")
    exit(1)
}
