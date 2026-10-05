import Foundation

print("=== Running Verification Test: Clean Workspace Anchor & Anti-Spurious Scroll Guard ===")

let rootPath = "/Users/heizaaa/Desktop/cdev/iza-3"
let ingressPath = "\(rootPath)/boringNotch/Clicky/Reasoning/Ingress/TaskIngressGateway.swift"
let plannerPath = "\(rootPath)/boringNotch/Clicky/Reasoning/Planner/TaskStepPlanner.swift"
let validatorPath = "\(rootPath)/boringNotch/Clicky/Reasoning/Validator/TaskEgressValidator.swift"
let loopPath = "\(rootPath)/boringNotch/Clicky/CUA/Loop/CompanionVMAgentLoop.swift"
let scrollToolPath = "\(rootPath)/boringNotch/Clicky/CUA/Actions/CUAScrollActionTool.swift"

var passed = 0
var total = 0

// Test 1: TaskIngressGateway prompt and decoder default general inbox/list inspection to targetIndex: 1
total += 1
let ingressPolicyPath = "\(rootPath)/boringNotch/Clicky/Reasoning/Ingress/Policies/IngressPolicy.swift"
if let rawContent = try? String(contentsOfFile: ingressPath, encoding: .utf8) {
    let policyContent = (try? String(contentsOfFile: ingressPolicyPath, encoding: .utf8)) ?? ""
    let content = rawContent + "\n" + policyContent
    let hasPromptInstruction = content.contains("set \"targetIndex\": 1 (the topmost latest item)")
    let hasDecoderFallback = content.contains("resolvedIndex = 1")

    if hasPromptInstruction && hasDecoderFallback {
        print("  ✅ [PASS] TaskIngressGateway defaults general inspect/read requests to targetIndex: 1")
        passed += 1
    } else {
        print("  ❌ [FAIL] TaskIngressGateway missing default targetIndex: 1 (prompt: \(hasPromptInstruction), decoder: \(hasDecoderFallback))")
    }
} else {
    print("  ❌ [FAIL] Cannot read \(ingressPath)")
}

// Test 2: TaskStepPlanner has ZERO literal few-shot number leaks (no index 10 / 1 to 9 leaks)
total += 1
let inspectPolicyPath = "\(rootPath)/boringNotch/Clicky/Reasoning/Planner/Policies/InspectStepPolicy.swift"
if let rawContent = try? String(contentsOfFile: plannerPath, encoding: .utf8) {
    let policyContent = (try? String(contentsOfFile: inspectPolicyPath, encoding: .utf8)) ?? ""
    let content = rawContent + "\n" + policyContent

    let hasLeaked10 = content.contains("target index 10") || content.contains("indices 1 to 9")
    let hasNoSpuriousScrollRule = content.contains("DILARANG KERAS / NEVER plan actionType: \"scroll_down\" or \"scroll_up\" when the target item is already visible in listItems")

    if !hasLeaked10 && hasNoSpuriousScrollRule {
        print("  ✅ [PASS] TaskStepPlanner has zero literal few-shot number leaks and forbids scroll when target is visible")
        passed += 1
    } else {
        print("  ❌ [FAIL] TaskStepPlanner has literal number leaks: \(hasLeaked10) or missing rule: \(hasNoSpuriousScrollRule)")
    }
} else {
    print("  ❌ [FAIL] Cannot read \(plannerPath)")
}

// Test 3: TaskEgressValidator has ZERO literal few-shot number leaks
total += 1
if let content = try? String(contentsOfFile: validatorPath, encoding: .utf8) {
    let hasLeaked10 = content.contains("index 10") || content.contains("index 9")

    if !hasLeaked10 {
        print("  ✅ [PASS] TaskEgressValidator has zero literal few-shot number leaks")
        passed += 1
    } else {
        print("  ❌ [FAIL] TaskEgressValidator has literal number leaks: \(hasLeaked10)")
    }
} else {
    print("  ❌ [FAIL] Cannot read \(validatorPath)")
}

// Test 4: CompanionVMAgentLoop enforces Anti-Spurious Scroll Guard
total += 1
if let content = try? String(contentsOfFile: loopPath, encoding: .utf8) {
    let hasSpuriousGuard = content.contains("Prevented spurious scroll: target item index")
    let hasClickOverride = content.contains("activeDecision = AFMStepDecision") && content.contains("actionType: \"click\"")

    if hasSpuriousGuard && hasClickOverride {
        print("  ✅ [PASS] CompanionVMAgentLoop enforces Anti-Spurious Scroll Guard (overrides scroll to click when item is visible)")
        passed += 1
    } else {
        print("  ❌ [FAIL] CompanionVMAgentLoop missing Anti-Spurious Scroll Guard")
    }
} else {
    print("  ❌ [FAIL] Cannot read \(loopPath)")
}

// Test 5: CUAScrollActionTool implements resetScrollToTop for Clean Workspace Anchor
total += 1
if let content = try? String(contentsOfFile: scrollToolPath, encoding: .utf8) {
    let hasResetFunc = content.contains("func resetScrollToTop(pid: pid_t)")
    let hasSetZero = content.contains("var zero: Float = 0.0")

    if hasResetFunc && hasSetZero {
        print("  ✅ [PASS] CUAScrollActionTool implements resetScrollToTop to guarantee Clean Workspace Anchor")
        passed += 1
    } else {
        print("  ❌ [FAIL] CUAScrollActionTool missing resetScrollToTop")
    }
} else {
    print("  ❌ [FAIL] Cannot read \(scrollToolPath)")
}

// Test 6: CompanionVMAgentLoop calls resetScrollToTop on task start
total += 1
if let content = try? String(contentsOfFile: loopPath, encoding: .utf8) {
    let hasResetCall = content.contains("CUAScrollActionTool.resetScrollToTop(pid: pid)")

    if hasResetCall {
        print("  ✅ [PASS] CompanionVMAgentLoop resets scroll to top (0.0) at task start for latest item inspection")
        passed += 1
    } else {
        print("  ❌ [FAIL] CompanionVMAgentLoop missing resetScrollToTop invocation")
    }
} else {
    print("  ❌ [FAIL] Cannot read \(loopPath)")
}

print("\n=== Summary: \(passed)/\(total) Tests Passed ===")
if passed == total {
    print("🏆 ALL TESTS PASSED!")
    exit(0)
} else {
    print("❌ SOME TESTS FAILED!")
    exit(1)
}
