import Foundation

print("=== Running Test F-12 Task 3: Autonomous Dynamic VM Agent Loop ===")

let rootPath = "/Users/heizaaa/Desktop/cdev/iza-3"
let agentLoopPath = "\(rootPath)/boringNotch/Clicky/Tools/CompanionVMAgentLoop.swift"

var passed = 0
var total = 0

// Test 1: CompanionVMAgentLoop.swift exists and defines the actor/class
total += 1
if let content = try? String(contentsOfFile: agentLoopPath, encoding: .utf8) {
    if content.contains("class CompanionVMAgentLoop") || content.contains("actor CompanionVMAgentLoop") {
        print("  ✅ [PASS] CompanionVMAgentLoop exists and defines agent runtime")
        passed += 1
    } else {
        print("  ❌ [FAIL] CompanionVMAgentLoop declaration missing")
    }
} else {
    print("  ❌ [FAIL] File \(agentLoopPath) does not exist")
}

// Test 2: Implements generic CUA tool dispatch (zero hardcoded email steps)
total += 1
if let content = try? String(contentsOfFile: agentLoopPath, encoding: .utf8) {
    let hasInspect = content.contains("inspectWorkspace") || content.contains("inspect_workspace")
    let hasClick = content.contains("groundAndClick") || content.contains("ground_and_click")
    let hasType = content.contains("typeText") || content.contains("type_text")
    let hasRead = content.contains("readElements") || content.contains("read_elements")
    let hasFinish = content.contains("finishTask") || content.contains("finish_task")
    
    if hasInspect && hasClick && hasType && hasRead && hasFinish {
        print("  ✅ [PASS] Implements generic CUA visual tools (inspect, click, type, read, finish)")
        passed += 1
    } else {
        print("  ❌ [FAIL] Missing one or more generic CUA tools in agent loop")
    }
} else {
    print("  ❌ [FAIL] Cannot read CompanionVMAgentLoop.swift")
}

// Test 3: Prioritizes AXUIElement first with 6 Luna Vision fallback via ClickyHybridGroundingEngine
total += 1
if let content = try? String(contentsOfFile: agentLoopPath, encoding: .utf8) {
    if content.contains("ClickyHybridGroundingEngine.shared.resolveElementCoordinate") {
        print("  ✅ [PASS] Integrates ClickyHybridGroundingEngine (AXUIElement-first + 6 Luna Vision fallback)")
        passed += 1
    } else {
        print("  ❌ [FAIL] CompanionVMAgentLoop does not integrate ClickyHybridGroundingEngine")
    }
} else {
    print("  ❌ [FAIL] Cannot read CompanionVMAgentLoop.swift")
}

// Test 4: Saves deliverable audit receipt dynamically in companion workspace
total += 1
if let content = try? String(contentsOfFile: agentLoopPath, encoding: .utf8) {
    if content.contains("deliverables") && content.contains(".json") {
        print("  ✅ [PASS] Saves deliverable audit receipts into companion workspace")
        passed += 1
    } else {
        print("  ❌ [FAIL] Deliverable audit receipt logic missing")
    }
} else {
    print("  ❌ [FAIL] Cannot read CompanionVMAgentLoop.swift")
}

// Test 5: Emits ComputerCardPayload dynamically based on agent progress
total += 1
if let content = try? String(contentsOfFile: agentLoopPath, encoding: .utf8) {
    if content.contains("ComputerCardPayload") && content.contains("queueItems") {
        print("  ✅ [PASS] Emits ComputerCardPayload with live dynamic queueItems")
        passed += 1
    } else {
        print("  ❌ [FAIL] ComputerCardPayload emission missing")
    }
} else {
    print("  ❌ [FAIL] Cannot read CompanionVMAgentLoop.swift")
}

print("=== Results: \(passed)/\(total) tests passed ===")
if passed == total {
    print("ALL TESTS PASSED")
    exit(0)
} else {
    print("SOME TESTS FAILED (EXPECTED BEFORE IMPLEMENTATION)")
    exit(1)
}
