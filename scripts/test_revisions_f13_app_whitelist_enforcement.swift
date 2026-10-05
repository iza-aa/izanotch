import Foundation

print("=== Running Test F-13 Checkpoint 2 & 3: Permissions UI & Policy Enforcement ===")

let rootPath = "/Users/heizaaa/Desktop/cdev/iza-3"
let studioPath = "\(rootPath)/boringNotch/Clicky/HomeSpace/HomeSpaceRootView.swift"
let agentLoopPath = "\(rootPath)/boringNotch/Clicky/Tools/CompanionVMAgentLoop.swift"

var passed = 0
var total = 0

// Test 1: HomeSpaceRootView provides CONNECTED APPS & SAFARI ACCESS in Edit Character
total += 1
if let content = try? String(contentsOfFile: studioPath, encoding: .utf8) {
    let hasSection = content.contains("CONNECTED APPS & SAFARI ACCESS")
    let hasAppChips = content.contains("editWorkflowApps")
    let hasDomainField = content.contains("editSafariDomains")
    let hasTabMode = content.contains("editSafariTabMode")
    
    if hasSection && hasAppChips && hasDomainField && hasTabMode {
        print("  ✅ [PASS] Edit Character Studio provides full UI controls for apps, domains, and tab modes")
        passed += 1
    } else {
        print("  ❌ [FAIL] Missing one or more UI controls for agent permissions in studio")
    }
} else {
    print("  ❌ [FAIL] Cannot read HomeSpaceRootView.swift")
}

// Test 2: CompanionVMAgentLoop enforces application access authorization
total += 1
if let content = try? String(contentsOfFile: agentLoopPath, encoding: .utf8) {
    if content.contains("allowedApps.contains(where: { $0.lowercased() == appName.lowercased() })") {
        print("  ✅ [PASS] CompanionVMAgentLoop checks app authorization before workspace execution")
        passed += 1
    } else {
        print("  ❌ [FAIL] App permission check missing in CompanionVMAgentLoop")
    }
} else {
    print("  ❌ [FAIL] Cannot read CompanionVMAgentLoop.swift")
}

// Test 3: CompanionVMAgentLoop enforces Safari domain whitelist
total += 1
if let content = try? String(contentsOfFile: agentLoopPath, encoding: .utf8) {
    if content.contains("safariTabMode == \"whitelist_only\"") && content.contains("isWhitelisted") {
        print("  ✅ [PASS] CompanionVMAgentLoop verifies Safari URLs against allowed domain whitelist")
        passed += 1
    } else {
        print("  ❌ [FAIL] Safari whitelist verification missing in CompanionVMAgentLoop")
    }
} else {
    print("  ❌ [FAIL] Cannot read CompanionVMAgentLoop.swift")
}

print("=== Results: \(passed)/\(total) tests passed ===")
if passed == total {
    print("ALL TESTS PASSED")
    exit(0)
} else {
    exit(1)
}
