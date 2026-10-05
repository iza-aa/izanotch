import XCTest
@testable import ClickyCUA
@testable import ClickyReasoning

final class TaskL_MasterDetailClickEnforcementTests: XCTestCase {
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

    // Assertion 1: TaskStepPlanner strictly enforces click on list item before read
    func testTaskStepPlannerMandatoryClickBeforeRead() {
        let rawContent = findFileContent([
            "boringNotch/Clicky/Reasoning/Planner/TaskStepPlanner.swift",
            "Packages/ClickyKit/Sources/ClickyReasoning/TaskStepPlanner.swift"
        ]) ?? ""
        let policyContent = findFileContent([
            "boringNotch/Clicky/Reasoning/Planner/Policies/InspectStepPolicy.swift",
            "Packages/ClickyKit/Sources/ClickyReasoning/InspectStepPolicy.swift"
        ]) ?? ""
        let content = rawContent + "\n" + policyContent

        let hasNeverRead = content.contains("NEVER use actionType: \"read\" on a list item row")
        let hasMustClick = content.contains("If Previous Steps do NOT include a \"click\" action on the target item, your actionType MUST be \"click\" on the target item in the list")

        XCTAssertTrue(hasNeverRead, "Must forbid actionType 'read' on list item rows")
        XCTAssertTrue(hasMustClick, "Must enforce actionType 'click' on the target item first")
    }

    // Assertion 2: TaskEgressValidator requires clicked row and preview pane content before isDone
    func testTaskEgressValidatorRequiresClickedRowAndPreviewPaneContent() {
        let rawContent = findFileContent([
            "boringNotch/Clicky/Reasoning/Validator/TaskEgressValidator.swift",
            "Packages/ClickyKit/Sources/ClickyReasoning/TaskEgressValidator.swift"
        ]) ?? ""
        let policyContent = findFileContent([
            "boringNotch/Clicky/Reasoning/Validator/Policies/InspectValidationPolicy.swift",
            "Packages/ClickyKit/Sources/ClickyReasoning/InspectValidationPolicy.swift"
        ]) ?? ""
        let content = rawContent + "\n" + policyContent

        let hasPreviewReq = content.contains("the task is ONLY accomplished (isDone: true) AFTER the target item was clicked and its content/message is visible in the preview/reading pane")
        let hasNoPremature = !content.contains("If target item details (index \\(targetIndexStr)) are visible in listItems, mark isDone: true")

        XCTAssertTrue(hasPreviewReq, "Must enforce preview reading pane content before isDone: true")
        XCTAssertTrue(hasNoPremature, "Must not allow premature completion")
    }

    // Assertion 3: Process check
    func testIzaNotchProcessRunning() {
        var proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
        proc.arguments = ["-x", "izaNotch"]
        try? proc.run()
        proc.waitUntilExit()

        if proc.terminationStatus != 0 {
            proc = Process()
            proc.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
            proc.arguments = ["-x", "boringNotch"]
            try? proc.run()
            proc.waitUntilExit()
        }

        XCTAssertEqual(proc.terminationStatus, 0, "izaNotch process must be active and running")
    }
}
