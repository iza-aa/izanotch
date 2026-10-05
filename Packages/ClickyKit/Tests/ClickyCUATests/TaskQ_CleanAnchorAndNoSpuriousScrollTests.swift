import XCTest
@testable import ClickyCUA
@testable import ClickyReasoning
@testable import ClickyAgent

final class TaskQ_CleanAnchorAndNoSpuriousScrollTests: XCTestCase {
    private var repoRoot: String {
        var url = URL(fileURLWithPath: #filePath)
        while url.path != "/" {
            let candidate = url.appendingPathComponent("izaNotch.xcodeproj")
            if FileManager.default.fileExists(atPath: candidate.path) {
                return url.path
            }
            url = url.deletingLastPathComponent()
        }
        return "/Users/heizaaa/Desktop/cdev/iza-3"
    }

    private func findFileContent(_ candidates: [String]) -> String? {
        for rel in candidates {
            let full = "\(repoRoot)/\(rel)"
            if let str = try? String(contentsOfFile: full, encoding: .utf8) {
                return str
            }
        }
        return nil
    }

    // Assertion 1: TaskIngressGateway prompt and decoder default general inbox/list inspection to targetIndex: 1
    func testTaskIngressGatewayDefaultsToTargetIndex1() {
        let rawContent = findFileContent([
            "boringNotch/Clicky/Reasoning/Ingress/TaskIngressGateway.swift",
            "Packages/ClickyKit/Sources/ClickyReasoning/TaskIngressGateway.swift"
        ]) ?? ""
        let policyContent = findFileContent([
            "boringNotch/Clicky/Reasoning/Ingress/Policies/IngressPolicy.swift",
            "Packages/ClickyKit/Sources/ClickyReasoning/IngressPolicy.swift"
        ]) ?? ""
        let content = rawContent + "\n" + policyContent

        let hasPromptInstruction = content.contains("set \"targetIndex\": 1 (the topmost latest item)")
        let hasDecoderFallback = content.contains("resolvedIndex = 1")

        XCTAssertTrue(hasPromptInstruction, "Prompt instruction must set targetIndex to 1")
        XCTAssertTrue(hasDecoderFallback, "Decoder fallback must resolve to 1")
    }

    // Assertion 2: TaskStepPlanner has ZERO literal few-shot number leaks and forbids scroll when target is visible
    func testTaskStepPlannerZeroLiteralFewShotNumberLeaksAndNoSpuriousScrollRule() {
        let rawContent = findFileContent([
            "boringNotch/Clicky/Reasoning/Planner/TaskStepPlanner.swift",
            "Packages/ClickyKit/Sources/ClickyReasoning/TaskStepPlanner.swift"
        ]) ?? ""
        let policyContent = findFileContent([
            "boringNotch/Clicky/Reasoning/Planner/Policies/InspectStepPolicy.swift",
            "Packages/ClickyKit/Sources/ClickyReasoning/InspectStepPolicy.swift"
        ]) ?? ""
        let content = rawContent + "\n" + policyContent

        let hasLeaked10 = content.contains("target index 10") || content.contains("indices 1 to 9")
        let hasNoSpuriousScrollRule = content.contains("DILARANG KERAS / NEVER plan actionType: \"scroll_down\" or \"scroll_up\" when the target item is already visible in listItems")

        XCTAssertFalse(hasLeaked10, "TaskStepPlanner must have zero literal few-shot number leaks")
        XCTAssertTrue(hasNoSpuriousScrollRule, "TaskStepPlanner must forbid spurious scroll when target is already visible")
    }

    // Assertion 3: TaskEgressValidator has ZERO literal few-shot number leaks
    func testTaskEgressValidatorZeroLiteralFewShotNumberLeaks() {
        let content = findFileContent([
            "boringNotch/Clicky/Reasoning/Validator/TaskEgressValidator.swift",
            "Packages/ClickyKit/Sources/ClickyReasoning/TaskEgressValidator.swift"
        ]) ?? ""

        let hasLeaked10 = content.contains("index 10") || content.contains("index 9")
        XCTAssertFalse(hasLeaked10, "TaskEgressValidator must have zero literal few-shot number leaks")
    }

    // Assertion 4: CompanionVMAgentLoop enforces Anti-Spurious Scroll Guard
    func testCompanionVMAgentLoopAntiSpuriousScrollGuard() {
        let content = findFileContent([
            "boringNotch/Clicky/CUA/Loop/CompanionVMAgentLoop.swift",
            "Packages/ClickyKit/Sources/ClickyAgent/CompanionVMAgentLoop.swift"
        ]) ?? ""

        let hasSpuriousGuard = content.contains("Prevented spurious scroll: target item index")
        let hasClickOverride = content.contains("activeDecision = AFMStepDecision") && content.contains("actionType: \"click\"")

        XCTAssertTrue(hasSpuriousGuard, "CompanionVMAgentLoop must contain Prevented spurious scroll log")
        XCTAssertTrue(hasClickOverride, "CompanionVMAgentLoop must override scroll to click action")
    }

    // Assertion 5: CUAScrollActionTool implements resetScrollToTop for Clean Workspace Anchor
    func testCUAScrollActionToolImplementsResetScrollToTop() {
        let content = findFileContent([
            "boringNotch/Clicky/CUA/Actions/CUAScrollActionTool.swift",
            "Packages/ClickyKit/Sources/ClickyCUA/CUAScrollActionTool.swift"
        ]) ?? ""

        let hasResetFunc = content.contains("func resetScrollToTop(pid: pid_t)")
        let hasSetZero = content.contains("var zero: Float = 0.0")

        XCTAssertTrue(hasResetFunc, "CUAScrollActionTool must implement resetScrollToTop")
        XCTAssertTrue(hasSetZero, "resetScrollToTop must set scroll position to 0.0")
    }

    // Assertion 6: CompanionVMAgentLoop calls resetScrollToTop on task start
    func testCompanionVMAgentLoopCallsResetScrollToTopOnTaskStart() {
        let content = findFileContent([
            "boringNotch/Clicky/CUA/Loop/CompanionVMAgentLoop.swift",
            "Packages/ClickyKit/Sources/ClickyAgent/CompanionVMAgentLoop.swift"
        ]) ?? ""

        let hasResetCall = content.contains("CUAScrollActionTool.resetScrollToTop(pid: pid)")
        XCTAssertTrue(hasResetCall, "CompanionVMAgentLoop must call resetScrollToTop on task start")
    }
}
