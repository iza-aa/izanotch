import Foundation

print("=== Running Verification Test: Task R - True Modular File Architecture for Policies ===")

let rootPath = "/Users/heizaaa/Desktop/cdev/iza-3"
let plannerPath = "\(rootPath)/boringNotch/Clicky/Reasoning/Planner/TaskStepPlanner.swift"
let validatorPath = "\(rootPath)/boringNotch/Clicky/Reasoning/Validator/TaskEgressValidator.swift"
let pbxprojPath = "\(rootPath)/boringNotch.xcodeproj/project.pbxproj"

var passed = 0
var total = 0

// Test 1: Dedicated Swift Policy files exist in Planner & Validator directories
total += 1
let policyFiles = [
    "\(rootPath)/boringNotch/Clicky/Reasoning/Planner/Policies/StepPolicyRegistry.swift",
    "\(rootPath)/boringNotch/Clicky/Reasoning/Planner/Policies/InspectStepPolicy.swift",
    "\(rootPath)/boringNotch/Clicky/Reasoning/Planner/Policies/ComposeStepPolicy.swift",
    "\(rootPath)/boringNotch/Clicky/Reasoning/Validator/Policies/ValidationPolicyRegistry.swift",
    "\(rootPath)/boringNotch/Clicky/Reasoning/Validator/Policies/InspectValidationPolicy.swift",
    "\(rootPath)/boringNotch/Clicky/Reasoning/Validator/Policies/ComposeValidationPolicy.swift"
]

var allFilesExist = true
for path in policyFiles {
    if !FileManager.default.fileExists(atPath: path) {
        print("  ❌ [FAIL] Missing file: \(path)")
        allFilesExist = false
    }
}

if allFilesExist {
    print("  ✅ [PASS] All 6 dedicated modular policy files exist in their respective directories")
    passed += 1
} else {
    print("  ❌ [FAIL] Some policy files are missing")
}

// Test 2: TaskStepPlanner is a clean orchestrator delegating to StepPolicyRegistry
total += 1
if let content = try? String(contentsOfFile: plannerPath, encoding: .utf8) {
    let delegatesToRegistry = content.contains("StepPolicyRegistry.policy(for: intentType)")
    let hasNoEmbeddedPromptBlock = !content.contains("func buildStepInstructions")
    let isCompact = content.components(separatedBy: .newlines).count < 200

    if delegatesToRegistry && hasNoEmbeddedPromptBlock && isCompact {
        print("  ✅ [PASS] TaskStepPlanner is a lean orchestrator delegating to StepPolicyRegistry")
        passed += 1
    } else {
        print("  ❌ [FAIL] TaskStepPlanner still contains embedded prompt blocks or does not delegate to registry")
    }
} else {
    print("  ❌ [FAIL] Cannot read \(plannerPath)")
}

// Test 3: TaskEgressValidator is a clean orchestrator with deterministic scroll guard
total += 1
if let content = try? String(contentsOfFile: validatorPath, encoding: .utf8) {
    let delegatesToRegistry = content.contains("ValidationPolicyRegistry.policy(for: intentType)")
    let hasShortCircuit = content.contains("Deterministic short-circuit: last step was scroll preparatory action. isDone=false.")
    let hasNoEmbeddedPromptBlock = !content.contains("func buildValidationInstructions")

    if delegatesToRegistry && hasShortCircuit && hasNoEmbeddedPromptBlock {
        print("  ✅ [PASS] TaskEgressValidator delegates to ValidationPolicyRegistry with deterministic scroll guard")
        passed += 1
    } else {
        print("  ❌ [FAIL] TaskEgressValidator missing delegation or deterministic guard")
    }
} else {
    print("  ❌ [FAIL] Cannot read \(validatorPath)")
}

// Test 4: All 6 policy files are registered in project.pbxproj
total += 1
if let pbxContent = try? String(contentsOfFile: pbxprojPath, encoding: .utf8) {
    let hasStepReg = pbxContent.contains("StepPolicyRegistry.swift in Sources")
    let hasInspectStep = pbxContent.contains("InspectStepPolicy.swift in Sources")
    let hasComposeStep = pbxContent.contains("ComposeStepPolicy.swift in Sources")
    let hasValReg = pbxContent.contains("ValidationPolicyRegistry.swift in Sources")
    let hasInspectVal = pbxContent.contains("InspectValidationPolicy.swift in Sources")
    let hasComposeVal = pbxContent.contains("ComposeValidationPolicy.swift in Sources")

    if hasStepReg && hasInspectStep && hasComposeStep && hasValReg && hasInspectVal && hasComposeVal {
        print("  ✅ [PASS] All 6 modular policy files are registered in Xcode project.pbxproj")
        passed += 1
    } else {
        print("  ❌ [FAIL] Some policy files are missing from project.pbxproj")
    }
} else {
    print("  ❌ [FAIL] Cannot read \(pbxprojPath)")
}

// Test 5: Modular Documentation Files exist
total += 1
let specPath = "\(rootPath)/docs/reasoning/INTENT_SPEC.md"
let policiesPath = "\(rootPath)/docs/reasoning/PROMPT_POLICIES.md"
let hasSpec = FileManager.default.fileExists(atPath: specPath)
let hasPolicies = FileManager.default.fileExists(atPath: policiesPath)

if hasSpec && hasPolicies {
    print("  ✅ [PASS] Modular reasoning documentation exists (INTENT_SPEC.md & PROMPT_POLICIES.md)")
    passed += 1
} else {
    print("  ❌ [FAIL] Modular documentation missing: spec=\(hasSpec), policies=\(hasPolicies)")
}

print("\n=== Summary: \(passed)/\(total) Tests Passed ===")
if passed == total {
    print("🏆 ALL TASK R MODULAR POLICY VERIFICATIONS PASSED!\n")
    exit(0)
} else {
    print("💥 SOME TESTS FAILED!\n")
    exit(1)
}
