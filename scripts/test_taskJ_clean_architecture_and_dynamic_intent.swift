import Foundation

var passed = 0
var failed = 0

func assertTest(_ condition: Bool, _ name: String) {
    if condition {
        print("✅ PASS: \(name)")
        passed += 1
    } else {
        print("❌ FAIL: \(name)")
        failed += 1
    }
}

print("=== Running TDD Test Suite: Task J (Clean Architecture & Dynamic Intent Gate) ===")

let repoRoot = "/Users/heizaaa/Desktop/cdev/iza-3"
let clickyRoot = repoRoot + "/boringNotch/Clicky"

// 1. Directory Structure Invariants: Old generic Clicky/Tools is gone
let toolsDir = clickyRoot + "/Tools"
assertTest(!FileManager.default.fileExists(atPath: toolsDir), "Clicky/Tools directory is completely dismantled and eliminated")

// 2. Clean Architecture Core Folders Exist
let expectedDirs = [
    clickyRoot + "/UI/HomeSpace",
    clickyRoot + "/UI/Rail",
    clickyRoot + "/UI/Floating",
    clickyRoot + "/UI/Avatars",
    clickyRoot + "/UI/Viewport",
    clickyRoot + "/UI/Common",
    clickyRoot + "/Reasoning/Ingress",
    clickyRoot + "/Reasoning/Planner",
    clickyRoot + "/Reasoning/Validator",
    clickyRoot + "/Reasoning/Coordination",
    clickyRoot + "/CUA/Loop",
    clickyRoot + "/CUA/Actions",
    clickyRoot + "/CUA/Grounding",
    clickyRoot + "/CUA/Execution",
    clickyRoot + "/Workspace/VirtualDisplay",
    clickyRoot + "/Workspace/Streaming",
    clickyRoot + "/Workspace/Discovery",
    clickyRoot + "/Workspace/WindowManagement",
    clickyRoot + "/Roster",
    clickyRoot + "/Services/Audio",
    clickyRoot + "/Services/Vision",
    clickyRoot + "/Services/Models",
    clickyRoot + "/Services/Domain/TradingView",
    clickyRoot + "/Services/Domain/Astronacci",
    clickyRoot + "/Services/Domain/FuturesScout",
    clickyRoot + "/Core"
]

for d in expectedDirs {
    let name = d.replacingOccurrences(of: clickyRoot + "/", with: "")
    assertTest(FileManager.default.fileExists(atPath: d), "Clean domain directory exists: \(name)")
}

// 3. Static Invariants on Key Architectural Files
let ingressPath = clickyRoot + "/Reasoning/Ingress/TaskIngressGateway.swift"
if let content = try? String(contentsOfFile: ingressPath, encoding: .utf8) {
    assertTest(content.contains("Intent Classification (Conversational vs Computer Action)"), "TaskIngressGateway contains explicit intent classification principles")
    assertTest(content.contains("requiresTakeoverOnCompletion"), "TaskIngressGateway supports requiresTakeoverOnCompletion contract")
    assertTest(content.contains("isConversational"), "TaskIngressGateway enforces conversational safety")
} else {
    assertTest(false, "Failed to read TaskIngressGateway.swift")
}

let contractPath = clickyRoot + "/Reasoning/Ingress/CanonicalTaskContract.swift"
if let content = try? String(contentsOfFile: contractPath, encoding: .utf8) {
    assertTest(content.contains("public let requiresTakeoverOnCompletion: Bool"), "AFMTaskDecomposition defines first-class requiresTakeoverOnCompletion")
    assertTest(content.contains("public var isConversational: Bool"), "AFMTaskDecomposition defines isConversational helper property")
} else {
    assertTest(false, "Failed to read CanonicalTaskContract.swift")
}

let vmLoopPath = clickyRoot + "/CUA/Loop/CompanionVMAgentLoop.swift"
if let content = try? String(contentsOfFile: vmLoopPath, encoding: .utf8) {
    assertTest(!content.contains("contains(\"kirim\")"), "CompanionVMAgentLoop has zero hardcoded 'kirim' string matching")
    assertTest(content.contains("taskPlan?.requiresTakeoverOnCompletion == true"), "CompanionVMAgentLoop checks autonomous requiresTakeoverOnCompletion contract")
} else {
    assertTest(false, "Failed to read CompanionVMAgentLoop.swift")
}

let egressPath = clickyRoot + "/Reasoning/Validator/TaskEgressValidator.swift"
if let content = try? String(contentsOfFile: egressPath, encoding: .utf8) {
    assertTest(content.contains("taskContract?.requiresTakeoverOnCompletion == true"), "TaskEgressValidator checks autonomous requiresTakeoverOnCompletion contract")
} else {
    assertTest(false, "Failed to read TaskEgressValidator.swift")
}

print("=== Summary: \(passed) passed, \(failed) failed ===")
exit(failed == 0 ? 0 : 1)
