import Foundation

// MARK: - TDD Test: Task 6 - Eradicate Dead Code MailWorkflowOperationTool AppleScript
print("[TDD_TEST] Starting Task 6 verification: Zero MailWorkflowOperationTool AppleScript...")

let projectDir = "/Users/heizaaa/Desktop/cdev/iza-3"
let toolFilePath = "\(projectDir)/boringNotch/Clicky/Tools/ClickyFunctionTool.swift"
let registryFilePath = "\(projectDir)/boringNotch/Clicky/Tools/ClickyFunctionToolRegistry.swift"

guard let toolSource = try? String(contentsOfFile: toolFilePath, encoding: .utf8),
      let registrySource = try? String(contentsOfFile: registryFilePath, encoding: .utf8) else {
    print("[FAIL] Cannot read source files.")
    exit(1)
}

var allPassed = true

// 1. Verify NO tell application "Mail" in ClickyFunctionTool.swift
if toolSource.contains("tell application \"Mail\"") {
    print("[FAIL] ClickyFunctionTool.swift still contains hardcoded AppleScript 'tell application \"Mail\"'!")
    allPassed = false
} else {
    print("[PASS] Verified: Zero 'tell application \"Mail\"' AppleScript in ClickyFunctionTool.swift.")
}

// 2. Verify MailWorkflowOperationTool removed from ClickyFunctionToolRegistry
if registrySource.contains("MailWorkflowOperationTool()") {
    print("[FAIL] ClickyFunctionToolRegistry still registers MailWorkflowOperationTool()!")
    allPassed = false
} else {
    print("[PASS] Verified: MailWorkflowOperationTool unregistered from ClickyFunctionToolRegistry.")
}

if allPassed {
    print("[SUCCESS] ALL TASK 6 TESTS PASSED!")
    exit(0)
} else {
    print("[TDD_RED] Task 6 requirements NOT yet fulfilled. Ready for implementation.")
    exit(2)
}
