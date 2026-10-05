import Foundation

print("=== Running Task D Test: Planner Anti-JSON-Path & Done Trigger Prompt ===")

let plannerPath = "/Users/heizaaa/Desktop/cdev/iza-3/boringNotch/Clicky/Tools/TaskStepPlanner.swift"
guard let content = try? String(contentsOf: URL(fileURLWithPath: plannerPath), encoding: .utf8) else {
    print("❌ Failed to read TaskStepPlanner.swift")
    exit(1)
}

if !content.contains("Do NOT use internal JSON paths") || !content.contains("listItems[") {
    print("❌ FAIL: TaskStepPlanner lacks explicit guard against internal JSON paths in targetElement")
    exit(1)
}

if !content.contains("If the requested item or information is already clearly observed") || !content.contains("actionType: \"done\"") {
    print("❌ FAIL: TaskStepPlanner lacks prompt trigger to conclude task when information is observed")
    exit(1)
}

print("✅ PASS: Task D Planner anti-JSON-path and done trigger guidelines verified successfully.")
exit(0)
