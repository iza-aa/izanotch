// scripts/test_revisions_f10_all.swift
import Foundation

print("=================================================================")
print("  🚀 FULL SUITE: FITUR F-10 (6 Luna Medium Vision VM & Pool)   ")
print("=================================================================")

var allPassed = true

func runTest(script: String, title: String) {
    print("\n--- Running: \(title) (\(script)) ---")
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/swift")
    process.arguments = [script]
    
    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = pipe
    
    do {
        try process.run()
        process.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        if let output = String(data: data, encoding: .utf8) {
            print(output.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        if process.terminationStatus != 0 {
            allPassed = false
            print("❌ FAIL: \(title)")
        } else {
            print("✅ PASS: \(title)")
        }
    } catch {
        allPassed = false
        print("❌ ERROR executing \(script): \(error)")
    }
}

runTest(script: "scripts/test_revisions_f10_chat_card_grounding.swift", title: "Task 1: Chat Card Live Mirroring & Precision Grounder")
runTest(script: "scripts/test_revisions_f10_codex_vision_service.swift", title: "Task 2: Backend Headless 6 Luna Medium Vision Service")
runTest(script: "scripts/test_revisions_f10_account_pool_manager.swift", title: "Task 3: Multi-Account Session Pool & Hot Failover")
runTest(script: "scripts/test_revisions_f10_notch_usage_widget.swift", title: "Task 4: Dynamic Island Notch AI ChatGPT Usage Widget")

print("\n=================================================================")
if allPassed {
    print("  🏆 ALL F-10 UNIT & INTEGRATION TESTS PASSED (100%)")
    print("=================================================================")
    exit(0)
} else {
    print("  ❌ SOME TESTS FAILED IN F-10 SUITE")
    print("=================================================================")
    exit(1)
}
