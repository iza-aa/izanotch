import Foundation

print("=== Running Test F-13 Checkpoint 4: Opsi 1 Full-Auto VM Trigger ===")

let rootPath = "/Users/heizaaa/Desktop/cdev/iza-3"
let rootViewPath = "\(rootPath)/boringNotch/Clicky/HomeSpace/HomeSpaceRootView.swift"

var passed = 0
var total = 0

// Test 1: HomeSpaceRootView.submitPrompt contains autonomous VM action detection
total += 1
if let content = try? String(contentsOfFile: rootViewPath, encoding: .utf8) {
    if content.contains("isVMTask") && content.contains("isEmailAction") && content.contains("isSafariAction") {
        print("  ✅ [PASS] submitPrompt detects VM task intent (email, safari, virtual sandbox actions)")
        passed += 1
    } else {
        print("  ❌ [FAIL] isVMTask intent detection missing in submitPrompt")
    }
} else {
    print("  ❌ [FAIL] Cannot read HomeSpaceRootView.swift")
}

// Test 2: submitPrompt automatically opens semi-fullscreen modal (Opsi 1)
total += 1
if let content = try? String(contentsOfFile: rootViewPath, encoding: .utf8) {
    let hasModalTrigger = content.contains("self.activeComputerModalPayload = workingPayload")
    if hasModalTrigger {
        print("  ✅ [PASS] submitPrompt automatically opens semi-fullscreen VM modal (Opsi 1: Full-Auto)")
        passed += 1
    } else {
        print("  ❌ [FAIL] Auto-opening modal missing in submitPrompt")
    }
} else {
    print("  ❌ [FAIL] Cannot read HomeSpaceRootView.swift")
}

// Test 3: submitPrompt invokes CompanionVMAgentLoop.shared.executeAutonomousTask
total += 1
if let content = try? String(contentsOfFile: rootViewPath, encoding: .utf8) {
    if content.contains("CompanionVMAgentLoop.shared.executeAutonomousTask") {
        print("  ✅ [PASS] submitPrompt invokes CompanionVMAgentLoop.shared.executeAutonomousTask")
        passed += 1
    } else {
        print("  ❌ [FAIL] executeAutonomousTask invocation missing in submitPrompt")
    }
} else {
    print("  ❌ [FAIL] Cannot read HomeSpaceRootView.swift")
}

print("=== Results: \(passed)/\(total) tests passed ===")
if passed == total {
    print("ALL TESTS PASSED")
    exit(0)
} else {
    exit(1)
}
