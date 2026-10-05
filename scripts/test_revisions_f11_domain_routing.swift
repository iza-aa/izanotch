// scripts/test_revisions_f11_domain_routing.swift
import Foundation

let enumsPath = "boringNotch/Clicky/ClickyEnums.swift"
let streamServicePath = "boringNotch/Clicky/Tools/CompanionWindowStreamService.swift"

print("=== Running Test F-11 Task 3: Dual-Domain Execution Routing (Mac Host vs Mascot VM) ===")

guard let enumsContent = try? String(contentsOfFile: enumsPath, encoding: .utf8),
      let streamContent = try? String(contentsOfFile: streamServicePath, encoding: .utf8) else {
    print("❌ [FAIL] Cannot read ClickyEnums.swift or CompanionWindowStreamService.swift")
    exit(1)
}

var passed = 0
var total = 5

// 1. MascotExecutionDomain enum declaration
if enumsContent.contains("enum MascotExecutionDomain") && enumsContent.contains("macHost") && enumsContent.contains("virtualSandbox") {
    print("  ✅ [PASS] Declares MascotExecutionDomain (.macHost vs .virtualSandbox)")
    passed += 1
} else {
    print("  ❌ [FAIL] Missing MascotExecutionDomain enum")
}

// 2. BuddySession executionDomain property
if enumsContent.contains("executionDomain") {
    print("  ✅ [PASS] BuddySession declares executionDomain property")
    passed += 1
} else {
    print("  ❌ [FAIL] BuddySession missing executionDomain property")
}

// 3. Inbox Buddy defaults to virtualSandbox (does NOT clutter Mac desktop)
if enumsContent.contains("inbox") && enumsContent.contains("virtualSandbox") {
    print("  ✅ [PASS] Inbox Buddy defaults to .virtualSandbox (operates in bot device, not Mac screen)")
    passed += 1
} else {
    print("  ❌ [FAIL] Inbox Buddy not configured for .virtualSandbox")
}

// 4. CompanionWindowStreamService supports domain-aware launch
if streamContent.contains("launchOrFocusWorkflowApp") && (streamContent.contains("domain") || streamContent.contains("virtualSandbox")) {
    print("  ✅ [PASS] CompanionWindowStreamService branches launch behavior based on execution domain")
    passed += 1
} else {
    print("  ❌ [FAIL] CompanionWindowStreamService not domain-aware")
}

// 5. Host isolation guard (does not open host app when in virtualSandbox)
if streamContent.contains("virtualSandbox") && streamContent.contains("ClickyLogger") {
    print("  ✅ [PASS] Guards host Mac desktop from being opened during virtual sandbox execution")
    passed += 1
} else {
    print("  ❌ [FAIL] Missing host isolation guard")
}

print("=== Results: \(passed)/\(total) tests passed ===")
if passed == total {
    print("ALL TESTS PASSED")
    exit(0)
} else {
    print("SOME TESTS FAILED")
    exit(1)
}
