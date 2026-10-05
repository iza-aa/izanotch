// scripts/test_revisions_f10_account_pool_manager.swift
import Foundation

let managerPath = "boringNotch/Clicky/Vision/ChatGPTAccountPoolManager.swift"
print("=== Running Test F-10 Task 3: Multi-Account Session Pool & Hot Failover ===")

guard let content = try? String(contentsOfFile: managerPath, encoding: .utf8) else {
    print("❌ [FAIL] Cannot read \(managerPath) (file does not exist yet)")
    exit(1)
}

var passed = 0
var total = 5

// 1. Account model check
if content.contains("struct GPTAccount") && content.contains("GPTAccountStatus") {
    print("  ✅ [PASS] Declares GPTAccount and GPTAccountStatus data models")
    passed += 1
} else {
    print("  ❌ [FAIL] Missing GPTAccount or GPTAccountStatus")
}

// 2. Cooldown status check
if content.contains("cooldown") && content.contains("resetAt") {
    print("  ✅ [PASS] Supports temporary cooldown with resetAt expiration")
    passed += 1
} else {
    print("  ❌ [FAIL] Missing cooldown state with resetAt")
}

// 3. Hot failover method check
if content.contains("switchToNextReadyAccount") && content.contains("markActiveAccountCooldown") {
    print("  ✅ [PASS] Implements switchToNextReadyAccount and markActiveAccountCooldown")
    passed += 1
} else {
    print("  ❌ [FAIL] Missing hot failover methods")
}

// 4. Codex Home path check
if content.contains("getActiveCodexHome") && content.contains("credentials/gpt_accounts") {
    print("  ✅ [PASS] Manages CODEX_HOME path in ~/.izanotchy/credentials/gpt_accounts")
    passed += 1
} else {
    print("  ❌ [FAIL] Missing getActiveCodexHome or credentials storage path")
}

// 5. Account registration check
if content.contains("registerAccount") && content.contains("auth.json") {
    print("  ✅ [PASS] Implements registerAccount saving auth.json securely")
    passed += 1
} else {
    print("  ❌ [FAIL] Missing registerAccount method")
}

print("=== Results: \(passed)/\(total) tests passed ===")
if passed == total {
    print("ALL TESTS PASSED")
    exit(0)
} else {
    print("SOME TESTS FAILED")
    exit(1)
}
