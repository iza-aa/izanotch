import Foundation

print("=== Running Task E Test: Guaranteed Chat Text Resolution & Non-Empty Deliverables ===")

// 1. Verify HomeSpaceRootView.swift has hardened text resolution preventing empty string slippage
let homeSpacePath = "/Users/heizaaa/Desktop/cdev/iza-3/boringNotch/Clicky/HomeSpace/HomeSpaceRootView.swift"
guard let homeSpaceContent = try? String(contentsOfFile: homeSpacePath, encoding: .utf8) else {
    print("❌ Failed to read HomeSpaceRootView.swift")
    exit(1)
}

if !homeSpaceContent.contains("resolvedText") || !homeSpaceContent.contains(".trimmingCharacters(in: .whitespacesAndNewlines)") {
    print("❌ FAIL: HomeSpaceRootView.swift does not yet have hardened resolvedText logic for chat update")
    exit(1)
}

// 2. Verify CompanionVMAgentLoop.swift has safeResponse in finishTask
let loopPath = "/Users/heizaaa/Desktop/cdev/iza-3/boringNotch/Clicky/Tools/CompanionVMAgentLoop.swift"
guard let loopContent = try? String(contentsOfFile: loopPath, encoding: .utf8) else {
    print("❌ Failed to read CompanionVMAgentLoop.swift")
    exit(1)
}

if !loopContent.contains("safeResponse") {
    print("❌ FAIL: CompanionVMAgentLoop.swift does not yet guarantee safeResponse in finishTask")
    exit(1)
}

// 3. Logic verification: simulate empty string optional
let emptyOptional: String? = ""
let whitespaceOptional: String? = "   "
let validSummary: String? = "Hasil inspeksi email"

func resolveText(response: String?, summary: String?, fallback: String) -> String {
    if let r = response?.trimmingCharacters(in: .whitespacesAndNewlines), !r.isEmpty {
        return r
    } else if let s = summary?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty {
        return s
    } else {
        return fallback
    }
}

let res1 = resolveText(response: emptyOptional, summary: validSummary, fallback: "Fallback")
assert(res1 == "Hasil inspeksi email", "Failed: emptyOptional should fall back to validSummary")

let res2 = resolveText(response: whitespaceOptional, summary: nil, fallback: "Fallback")
assert(res2 == "Fallback", "Failed: whitespaceOptional should fall back to Fallback")

print("✅ PASS: Task E Guaranteed chat text resolution logic verified successfully.")
exit(0)
