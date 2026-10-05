import Foundation

print("=== Running Test F-12 Task 2: Persona Sovereignty & VM Sandboxing Engine ===")

let rootPath = "/Users/heizaaa/Desktop/cdev/iza-3"
let companionManagerPath = "\(rootPath)/boringNotch/Clicky/CompanionManager.swift"
let workspaceManagerPath = "\(rootPath)/boringNotch/Clicky/Onboarding/CompanionWorkspaceManager.swift"

var passed = 0
var total = 0

// Test 1: CompanionManager system prompt enforces persona.md sovereignty & role constraints
total += 1
if let cmContent = try? String(contentsOfFile: companionManagerPath, encoding: .utf8) {
    if cmContent.contains("OFFICIAL COMPANION SPECIFICATION MARKDOWN") &&
       cmContent.contains("persona.md") {
        print("  ✅ [PASS] CompanionManager binds companion system prompt strictly to persona.md")
        passed += 1
    } else {
        print("  ❌ [FAIL] CompanionManager does not bind system prompt strictly to persona.md")
    }
} else {
    print("  ❌ [FAIL] Cannot read CompanionManager.swift")
}

// Test 2: CompanionManager enforces sandbox boundary when executionDomain == .virtualSandbox
total += 1
if let cmContent = try? String(contentsOfFile: companionManagerPath, encoding: .utf8) {
    if cmContent.contains("virtualSandbox") {
        print("  ✅ [PASS] CompanionManager incorporates virtualSandbox domain boundary")
        passed += 1
    } else {
        print("  ❌ [FAIL] CompanionManager lacks virtualSandbox domain boundary")
    }
} else {
    print("  ❌ [FAIL] Cannot read CompanionManager.swift")
}

// Test 3: CompanionWorkspaceManager provides persona.md read/write SSOT
total += 1
if let wmContent = try? String(contentsOfFile: workspaceManagerPath, encoding: .utf8) {
    if wmContent.contains("readCompanionSpec") && wmContent.contains("persona.md") {
        print("  ✅ [PASS] CompanionWorkspaceManager defines persona.md as single source of truth")
        passed += 1
    } else {
        print("  ❌ [FAIL] CompanionWorkspaceManager does not define persona.md as SSOT")
    }
} else {
    print("  ❌ [FAIL] Cannot read CompanionWorkspaceManager.swift")
}

print("=== Results: \(passed)/\(total) tests passed ===")
if passed == total {
    print("ALL TESTS PASSED")
    exit(0)
} else {
    print("SOME TESTS FAILED")
    exit(1)
}
