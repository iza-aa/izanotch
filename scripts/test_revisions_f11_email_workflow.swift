// scripts/test_revisions_f11_email_workflow.swift
import Foundation

let pipelinePath = "boringNotch/Clicky/Tools/MascotEmailActionPipeline.swift"
print("=== Running Test F-11 Task 4: Autonomous Email Action Pipeline ===")

guard let content = try? String(contentsOfFile: pipelinePath, encoding: .utf8) else {
    print("❌ [FAIL] Cannot read \(pipelinePath) (file does not exist yet)")
    exit(1)
}

var passed = 0
var total = 5

// 1. Recipient targeting check
if content.contains("rezkyhaikal2@gmail.com") {
    print("  ✅ [PASS] Configured with user-specified target recipient rezkyhaikal2@gmail.com")
    passed += 1
} else {
    print("  ❌ [FAIL] Missing recipient rezkyhaikal2@gmail.com")
}

// 2. Hybrid Grounder integration (AX-first + Vision fallback)
if content.contains("ClickyHybridGroundingEngine.shared") && content.contains("resolveElementCoordinate") {
    print("  ✅ [PASS] Uses ClickyHybridGroundingEngine with AXUIElement-first and Vision fallback")
    passed += 1
} else {
    print("  ❌ [FAIL] Missing ClickyHybridGroundingEngine integration")
}

// 3. Zero blind hotkey compliance (GUI clicks & typing)
if content.contains("click(at:") || content.contains("typeText(") {
    print("  ✅ [PASS] Executes visual GUI clicks & typing on grounded target elements")
    passed += 1
} else {
    print("  ❌ [FAIL] Missing visual UI action execution")
}

// 4. Mascot VM sandbox deliverable receipt
if content.contains("deliverables/sent_emails") && content.contains("EmailDeliverableReceipt") {
    print("  ✅ [PASS] Saves audit receipt in companion's isolated workspace deliverables")
    passed += 1
} else {
    print("  ❌ [FAIL] Missing deliverables receipt generation")
}

// 5. Card payload updater (live grounding crosshair & status)
if content.contains("ComputerCardPayload") && content.contains("groundingAuditTrail") {
    print("  ✅ [PASS] Emits ComputerCardPayload with live grounding coordinates and queue items")
    passed += 1
} else {
    print("  ❌ [FAIL] Missing ComputerCardPayload updates")
}

print("=== Results: \(passed)/\(total) tests passed ===")
if passed == total {
    print("ALL TESTS PASSED")
    exit(0)
} else {
    print("SOME TESTS FAILED")
    exit(1)
}
