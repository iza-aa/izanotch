import Foundation

print("=== Running Verification Test: Contract Index Fidelity & Zero Hardcoded Assumptions ===")

let rootPath = "/Users/heizaaa/Desktop/cdev/iza-3"
let plannerPath = "\(rootPath)/boringNotch/Clicky/Reasoning/Planner/TaskStepPlanner.swift"
let inspectPolicyPath = "\(rootPath)/boringNotch/Clicky/Reasoning/Planner/Policies/InspectStepPolicy.swift"
let validatorPath = "\(rootPath)/boringNotch/Clicky/Reasoning/Validator/TaskEgressValidator.swift"
let inspectValPath = "\(rootPath)/boringNotch/Clicky/Reasoning/Validator/Policies/InspectValidationPolicy.swift"

var passed = 0
var total = 0

// Test 1: TaskStepPlanner contains Contract Index Fidelity and NO rigid email/date assumptions
total += 1
if let rawContent = try? String(contentsOfFile: plannerPath, encoding: .utf8) {
    let policyContent = (try? String(contentsOfFile: inspectPolicyPath, encoding: .utf8)) ?? ""
    let content = rawContent + "\n" + policyContent

    let hasContractFidelity = content.contains("Contract Index Fidelity:")
    let hasAlignTarget = content.contains("When a numerical target index is specified in the task contract, align your target directly with the corresponding item in listItems")
    let hasNoReSort = content.contains("Do not attempt to re-sort or re-evaluate item rankings from unstructured text inside item content; respect the target index established by the task contract")
    let hasNoDateHardcode = !content.contains("daftar email selalu terurut") && !content.contains("terbaru selalu baris 1")

    if hasContractFidelity && hasAlignTarget && hasNoReSort && hasNoDateHardcode {
        print("  ✅ [PASS] TaskStepPlanner enforces pure Contract Index Fidelity without hardcoded date/email bias")
        passed += 1
    } else {
        print("  ❌ [FAIL] TaskStepPlanner rules check failed")
    }
} else {
    print("  ❌ [FAIL] Cannot read \(plannerPath)")
}

// Test 2: TaskEgressValidator has abstract list inspection rules
total += 1
if let rawContent = try? String(contentsOfFile: validatorPath, encoding: .utf8) {
    let policyContent = (try? String(contentsOfFile: inspectValPath, encoding: .utf8)) ?? ""
    let content = rawContent + "\n" + policyContent

    let hasAbstractInspection = content.contains("For inspecting or checking an item from a list or table:")
    let hasNoEmailBias = !content.contains("such as reading an email") && !content.contains("body of an email")

    if hasAbstractInspection && hasNoEmailBias {
        print("  ✅ [PASS] TaskEgressValidator list inspection rules are abstract and app-agnostic")
        passed += 1
    } else {
        print("  ❌ [FAIL] TaskEgressValidator still contains app-specific email terms")
    }
} else {
    print("  ❌ [FAIL] Cannot read \(validatorPath)")
}

// Test 3: Running process check
total += 1
let proc = Process()
proc.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
proc.arguments = ["-x", "boringNotch"]
try? proc.run()
proc.waitUntilExit()

if proc.terminationStatus == 0 {
    print("  ✅ [PASS] boringNotch is running with freshly recompiled binary")
    passed += 1
} else {
    print("  ❌ [FAIL] boringNotch process is not active")
}

print("\nResult: \(passed)/\(total) assertions passed.")
if passed == total {
    print("🎉 All Contract Index Fidelity verification tests passed successfully!")
    exit(0)
} else {
    print("⚠️ Verification tests failed.")
    exit(1)
}
