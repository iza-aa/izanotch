import Foundation

print("=== Running Task C Test: Validator Response Fallback & Early Loop Exit ===")

let valPath = "/Users/heizaaa/Desktop/cdev/iza-3/boringNotch/Clicky/Tools/TaskEgressValidator.swift"
guard let valContent = try? String(contentsOf: URL(fileURLWithPath: valPath), encoding: .utf8) else {
    print("❌ Failed to read TaskEgressValidator.swift")
    exit(1)
}

// 1. Check that parseValidationJSON checks multiple key variations and falls back to systemState
if !valContent.contains("dict[\"response\"]") || !valContent.contains("dict[\"answer\"]") {
    print("❌ FAIL: TaskEgressValidator does not support key variations like 'response' or 'answer'")
    exit(1)
}

if !valContent.contains("responseToUser.isEmpty") || !valContent.contains("responseToUser = systemState") {
    print("❌ FAIL: TaskEgressValidator lacks fallback from empty responseToUser to systemState")
    exit(1)
}

// 2. Check CompanionVMAgentLoop early exit and non-empty response guarantee
let loopPath = "/Users/heizaaa/Desktop/cdev/iza-3/boringNotch/Clicky/Tools/CompanionVMAgentLoop.swift"
guard let loopContent = try? String(contentsOf: URL(fileURLWithPath: loopPath), encoding: .utf8) else {
    print("❌ Failed to read CompanionVMAgentLoop.swift")
    exit(1)
}

if !loopContent.contains("effectiveResp") {
    print("❌ FAIL: CompanionVMAgentLoop does not resolve effective non-empty response before checking break condition")
    exit(1)
}

print("✅ PASS: Task C Validator response fallback and early exit verified successfully.")
exit(0)
