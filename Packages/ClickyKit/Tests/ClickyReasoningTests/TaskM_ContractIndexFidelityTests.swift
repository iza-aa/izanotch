import XCTest
@testable import ClickyReasoning

final class TaskM_ContractIndexFidelityTests: XCTestCase {
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

    // Assertion 1: TaskStepPlanner contains Contract Index Fidelity and NO rigid email/date assumptions
    func testContractIndexFidelityWithoutHardcodedAssumptions() {
        let rawContent = findFileContent([
            "boringNotch/Clicky/Reasoning/Planner/TaskStepPlanner.swift",
            "Packages/ClickyKit/Sources/ClickyReasoning/TaskStepPlanner.swift"
        ]) ?? ""
        let policyContent = findFileContent([
            "boringNotch/Clicky/Reasoning/Planner/Policies/InspectStepPolicy.swift",
            "Packages/ClickyKit/Sources/ClickyReasoning/InspectStepPolicy.swift"
        ]) ?? ""
        let content = rawContent + "\n" + policyContent

        let hasContractFidelity = content.contains("Contract Index Fidelity:")
        let hasAlignTarget = content.contains("When a numerical target index is specified in the task contract, align your target directly with the corresponding item in listItems")
        let hasNoReSort = content.contains("Do not attempt to re-sort or re-evaluate item rankings from unstructured text inside item content; respect the target index established by the task contract")
        let hasNoDateHardcode = !content.contains("daftar email selalu terurut") && !content.contains("terbaru selalu baris 1")

        XCTAssertTrue(hasContractFidelity, "Must specify Contract Index Fidelity")
        XCTAssertTrue(hasAlignTarget, "Must align target directly with corresponding item in listItems")
        XCTAssertTrue(hasNoReSort, "Must not re-sort from unstructured text")
        XCTAssertTrue(hasNoDateHardcode, "Must not contain rigid date or email ordering assumptions")
    }

    // Assertion 2: TaskEgressValidator has abstract list inspection rules
    func testTaskEgressValidatorAbstractListInspectionRules() {
        let rawContent = findFileContent([
            "boringNotch/Clicky/Reasoning/Validator/TaskEgressValidator.swift",
            "Packages/ClickyKit/Sources/ClickyReasoning/TaskEgressValidator.swift"
        ]) ?? ""
        let policyContent = findFileContent([
            "boringNotch/Clicky/Reasoning/Validator/Policies/InspectValidationPolicy.swift",
            "Packages/ClickyKit/Sources/ClickyReasoning/InspectValidationPolicy.swift"
        ]) ?? ""
        let content = rawContent + "\n" + policyContent

        let hasAbstractInspection = content.contains("For inspecting or checking an item from a list or table:")
        let hasNoEmailBias = !content.contains("such as reading an email") && !content.contains("body of an email")

        XCTAssertTrue(hasAbstractInspection, "TaskEgressValidator must have abstract list inspection rules")
        XCTAssertTrue(hasNoEmailBias, "TaskEgressValidator must not contain app-specific email terms")
    }

    // Assertion 3: Running process check
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
