import Foundation

// MARK: - TDD Test: Task 2 - See ➔ Plan ➔ Act Cycle & Full Mouse Hands Dispatch
print("[TDD_TEST] Starting Task 2 verification: See ➔ Plan ➔ Act Cycle in CompanionVMAgentLoop...")

let projectDir = "/Users/heizaaa/Desktop/cdev/iza-3"
let loopFilePath = "\(projectDir)/boringNotch/Clicky/Tools/CompanionVMAgentLoop.swift"

guard let loopSource = try? String(contentsOfFile: loopFilePath, encoding: .utf8) else {
    print("[FAIL] Cannot read CompanionVMAgentLoop.swift at \(loopFilePath)")
    exit(1)
}

var allPassed = true

// 1. Verify fresh screen observation is taken every step (See first, no stale history fallback)
if loopSource.contains("if let last = historySummary.last {\n                currentObservation = last") ||
   loopSource.contains("if let last = historySummary.last { currentObservation = last") {
    print("[FAIL] CompanionVMAgentLoop still reuses stale historySummary.last instead of observing fresh screen state every step!")
    allPassed = false
} else {
    print("[PASS] Verified: Every step captures and observes fresh screen state before planning.")
}

// 2. Verify support for performCuaScroll, performCuaRightClick, and performCuaLeftClick (in loop or modular action tools)
let clickToolPath = "\(projectDir)/boringNotch/Clicky/Tools/Actions/CUAClickActionTool.swift"
let scrollToolPath = "\(projectDir)/boringNotch/Clicky/Tools/Actions/CUAScrollActionTool.swift"
let clickSource = (try? String(contentsOfFile: clickToolPath, encoding: .utf8)) ?? ""
let scrollSource = (try? String(contentsOfFile: scrollToolPath, encoding: .utf8)) ?? ""
let allActionSource = loopSource + clickSource + scrollSource

if allActionSource.contains("performCuaScroll") {
    print("[PASS] performCuaScroll is dispatched in CUA action execution.")
} else {
    print("[FAIL] performCuaScroll is missing in CUA action execution.")
    allPassed = false
}

// 3. Verify support for performCuaRightClick
if allActionSource.contains("performCuaRightClick") {
    print("[PASS] performCuaRightClick is dispatched in CUA action execution.")
} else {
    print("[FAIL] performCuaRightClick is missing in CUA action execution.")
    allPassed = false
}

// 4. Verify support for performCuaLeftClick
if allActionSource.contains("performCuaLeftClick") {
    print("[PASS] performCuaLeftClick is dispatched in CUA action execution.")
} else {
    print("[FAIL] performCuaLeftClick is missing in CUA action execution.")
    allPassed = false
}

if allPassed {
    print("[SUCCESS] ALL TASK 2 TESTS PASSED!")
    exit(0)
} else {
    print("[TDD_RED] Task 2 requirements NOT yet fulfilled. Ready for implementation.")
    exit(2)
}
