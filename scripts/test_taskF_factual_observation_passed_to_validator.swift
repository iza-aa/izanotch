import Foundation

print("=== Running Task F Test: Factual Screen Observation Passed to Validator ===")

let loopPath = "/Users/heizaaa/Desktop/cdev/iza-3/boringNotch/Clicky/Tools/CompanionVMAgentLoop.swift"
guard let loopContent = try? String(contentsOfFile: loopPath, encoding: .utf8) else {
    print("❌ Failed to read CompanionVMAgentLoop.swift")
    exit(1)
}

// 1. Verify that 'AFM marked task done' fallback is eliminated and currentObservation is passed
if loopContent.contains("\"AFM marked task done\"") {
    print("❌ FAIL: CompanionVMAgentLoop.swift still passes dummy string 'AFM marked task done' to validator instead of currentObservation")
    exit(1)
}

// 2. Verify that latestObservation passes currentObservation on early finish
if !loopContent.contains("latestObservation: currentObservation") {
    print("❌ FAIL: CompanionVMAgentLoop.swift does not pass currentObservation to validateWithAFM on early finish")
    exit(1)
}

// 3. Verify that TaskEgressValidator explicitly forbids generic process phrases without data
let valPath = "/Users/heizaaa/Desktop/cdev/iza-3/boringNotch/Clicky/Tools/TaskEgressValidator.swift"
guard let valContent = try? String(contentsOfFile: valPath, encoding: .utf8) else {
    print("❌ Failed to read TaskEgressValidator.swift")
    exit(1)
}

if !valContent.contains("NEVER output generic process status") && !valContent.contains("proses inspeksi") {
    print("❌ FAIL: TaskEgressValidator instructions do not explicitly forbid generic process statements without actual findings")
    exit(1)
}

print("✅ PASS: Task F verified successfully.")
exit(0)
