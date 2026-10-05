import Foundation

print("=== Running Task 8 Test: Abstract Task Planner & Egress Prompts ===")

let plannerPath = "/Users/heizaaa/Desktop/cdev/iza-3/boringNotch/Clicky/Tools/TaskStepPlanner.swift"
guard let plannerContent = try? String(contentsOfFile: plannerPath) else {
    print("❌ Failed to read TaskStepPlanner.swift")
    exit(1)
}

// 1. Check for hardcoded Mail leaks in TaskStepPlanner
let hardcodedTokens = [
    "All Inboxes",
    "compose or draft window",
    "click To/Subject/Body",
    "Send button"
]

var foundHardcoded: [String] = []
for token in hardcodedTokens {
    if plannerContent.localizedCaseInsensitiveContains(token) {
        foundHardcoded.append(token)
    }
}

if !foundHardcoded.isEmpty {
    print("❌ FAIL: TaskStepPlanner contains hardcoded tokens: \(foundHardcoded)")
    exit(1)
}

// 2. Check that universal mouse actions are documented in instructions
let expectedActionTypes = [
    "read",
    "click",
    "right_click",
    "scroll_up",
    "scroll_down",
    "press_and_hold",
    "type",
    "done"
]

for action in expectedActionTypes {
    if !plannerContent.contains(action) {
        print("❌ FAIL: TaskStepPlanner instructions missing universal action type: '\(action)'")
        exit(1)
    }
}

// 3. Check TaskEgressValidator.swift for generalized language
let validatorPath = "/Users/heizaaa/Desktop/cdev/iza-3/boringNotch/Clicky/Tools/TaskEgressValidator.swift"
guard let validatorContent = try? String(contentsOfFile: validatorPath) else {
    print("❌ Failed to read TaskEgressValidator.swift")
    exit(1)
}

if validatorContent.contains("Email \\(ordStr) dari atas telah diperiksa") {
    print("❌ FAIL: TaskEgressValidator has hardcoded 'Email' for ordinal items instead of universal application item")
    exit(1)
}

print("✅ PASS: Task 8 abstract prompt guidelines verified successfully.")
exit(0)
