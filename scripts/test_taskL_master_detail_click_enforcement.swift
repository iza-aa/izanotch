import Foundation

print("=== Running Verification Test: Master-Detail Click Enforcement & Non-Premature Validation ===")

let rootPath = "/Users/heizaaa/Desktop/cdev/iza-3"
let plannerPath = "\(rootPath)/boringNotch/Clicky/Reasoning/Planner/TaskStepPlanner.swift"
let inspectPolicyPath = "\(rootPath)/boringNotch/Clicky/Reasoning/Planner/Policies/InspectStepPolicy.swift"
let validatorPath = "\(rootPath)/boringNotch/Clicky/Reasoning/Validator/TaskEgressValidator.swift"
let inspectValPath = "\(rootPath)/boringNotch/Clicky/Reasoning/Validator/Policies/InspectValidationPolicy.swift"

var passed = 0
var total = 0

// Test 1: TaskStepPlanner strictly enforces click on list item before read
total += 1
if let rawContent = try? String(contentsOfFile: plannerPath, encoding: .utf8) {
    let policyContent = (try? String(contentsOfFile: inspectPolicyPath, encoding: .utf8)) ?? ""
    let content = rawContent + "\n" + policyContent

    let hasNeverRead = content.contains("NEVER use actionType: \"read\" on a list item row")
    let hasMustClick = content.contains("If Previous Steps do NOT include a \"click\" action on the target item, your actionType MUST be \"click\" on the target item in the list")
    
    if hasNeverRead && hasMustClick {
        print("  ✅ [PASS] TaskStepPlanner enforces mandatory click on list item rows")
        passed += 1
    } else {
        print("  ❌ [FAIL] TaskStepPlanner missing click enforcement rules (hasNeverRead: \(hasNeverRead), hasMustClick: \(hasMustClick))")
    }
} else {
    print("  ❌ [FAIL] Cannot read \(plannerPath)")
}

// Test 2: TaskEgressValidator requires clicked row and preview pane content before isDone
total += 1
if let rawContent = try? String(contentsOfFile: validatorPath, encoding: .utf8) {
    let policyContent = (try? String(contentsOfFile: inspectValPath, encoding: .utf8)) ?? ""
    let content = rawContent + "\n" + policyContent

    let hasPreviewReq = content.contains("the task is ONLY accomplished (isDone: true) AFTER the target item was clicked and its content/message is visible in the preview/reading pane")
    let hasNoPremature = !content.contains("If target item details (index \\(targetIndexStr)) are visible in listItems, mark isDone: true")
    
    if hasPreviewReq && hasNoPremature {
        print("  ✅ [PASS] TaskEgressValidator strictly requires target item click & preview pane content before isDone")
        passed += 1
    } else {
        print("  ❌ [FAIL] TaskEgressValidator still has premature completion or missing preview requirement")
    }
} else {
    print("  ❌ [FAIL] Cannot read \(validatorPath)")
}

// Test 3: Process check
total += 1
let proc = Process()
proc.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
proc.arguments = ["-x", "boringNotch"]
try? proc.run()
proc.waitUntilExit()

if proc.terminationStatus == 0 {
    print("  ✅ [PASS] boringNotch is running with fresh binary")
    passed += 1
} else {
    print("  ❌ [FAIL] boringNotch is not active")
}

print("\nResult: \(passed)/\(total) passed.")
if passed == total {
    print("🎉 All Master-Detail verification tests passed successfully!")
    exit(0)
} else {
    print("⚠️ Verification tests failed.")
    exit(1)
}
