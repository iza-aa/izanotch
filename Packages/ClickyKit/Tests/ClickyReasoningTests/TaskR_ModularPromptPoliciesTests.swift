import XCTest
@testable import ClickyReasoning

final class TaskR_ModularPromptPoliciesTests: XCTestCase {
    private var repoRoot: String {
        var url = URL(fileURLWithPath: #filePath)
        while url.path != "/" {
            let candidate = url.appendingPathComponent("boringNotch.xcodeproj")
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

    private func fileExistsInAny(_ candidates: [String]) -> Bool {
        for rel in candidates {
            let full = "\(repoRoot)/\(rel)"
            if FileManager.default.fileExists(atPath: full) {
                return true
            }
        }
        return false
    }

    // Assertion 1: Dedicated Swift Policy files exist in Planner & Validator directories
    func testDedicatedModularPolicyFilesExist() {
        let policyFiles = [
            [
                "boringNotch/Clicky/Reasoning/Planner/Policies/StepPolicyRegistry.swift",
                "Packages/ClickyKit/Sources/ClickyReasoning/StepPolicyRegistry.swift"
            ],
            [
                "boringNotch/Clicky/Reasoning/Planner/Policies/InspectStepPolicy.swift",
                "Packages/ClickyKit/Sources/ClickyReasoning/InspectStepPolicy.swift"
            ],
            [
                "boringNotch/Clicky/Reasoning/Planner/Policies/ComposeStepPolicy.swift",
                "Packages/ClickyKit/Sources/ClickyReasoning/ComposeStepPolicy.swift"
            ],
            [
                "boringNotch/Clicky/Reasoning/Validator/Policies/ValidationPolicyRegistry.swift",
                "Packages/ClickyKit/Sources/ClickyReasoning/ValidationPolicyRegistry.swift"
            ],
            [
                "boringNotch/Clicky/Reasoning/Validator/Policies/InspectValidationPolicy.swift",
                "Packages/ClickyKit/Sources/ClickyReasoning/InspectValidationPolicy.swift"
            ],
            [
                "boringNotch/Clicky/Reasoning/Validator/Policies/ComposeValidationPolicy.swift",
                "Packages/ClickyKit/Sources/ClickyReasoning/ComposeValidationPolicy.swift"
            ]
        ]

        for candidates in policyFiles {
            XCTAssertTrue(fileExistsInAny(candidates), "Missing policy file candidates: \(candidates)")
        }
    }

    // Assertion 2: TaskStepPlanner is a clean orchestrator delegating to StepPolicyRegistry
    func testTaskStepPlannerDelegationAndCompactness() {
        let content = findFileContent([
            "boringNotch/Clicky/Reasoning/Planner/TaskStepPlanner.swift",
            "Packages/ClickyKit/Sources/ClickyReasoning/TaskStepPlanner.swift"
        ])
        XCTAssertNotNil(content, "Cannot read TaskStepPlanner.swift")
        guard let content = content else { return }

        let delegatesToRegistry = content.contains("StepPolicyRegistry.policy(for: intentType)")
        let hasNoEmbeddedPromptBlock = !content.contains("func buildStepInstructions")
        let isCompact = content.components(separatedBy: .newlines).count < 200

        XCTAssertTrue(delegatesToRegistry, "TaskStepPlanner should delegate to StepPolicyRegistry")
        XCTAssertTrue(hasNoEmbeddedPromptBlock, "TaskStepPlanner should not contain embedded prompt blocks")
        XCTAssertTrue(isCompact, "TaskStepPlanner should be compact (< 200 lines)")
    }

    // Assertion 3: TaskEgressValidator delegates to ValidationPolicyRegistry with deterministic scroll guard
    func testTaskEgressValidatorDelegationAndDeterministicScrollGuard() {
        let content = findFileContent([
            "boringNotch/Clicky/Reasoning/Validator/TaskEgressValidator.swift",
            "Packages/ClickyKit/Sources/ClickyReasoning/TaskEgressValidator.swift"
        ])
        XCTAssertNotNil(content, "Cannot read TaskEgressValidator.swift")
        guard let content = content else { return }

        let delegatesToRegistry = content.contains("ValidationPolicyRegistry.policy(for: intentType)")
        let hasShortCircuit = content.contains("Deterministic short-circuit: last step was scroll preparatory action. isDone=false.")
        let hasNoEmbeddedPromptBlock = !content.contains("func buildValidationInstructions")

        XCTAssertTrue(delegatesToRegistry, "TaskEgressValidator should delegate to ValidationPolicyRegistry")
        XCTAssertTrue(hasShortCircuit, "TaskEgressValidator should contain deterministic scroll short-circuit guard")
        XCTAssertTrue(hasNoEmbeddedPromptBlock, "TaskEgressValidator should not contain embedded prompt blocks")
    }

    // Assertion 4: All 6 policy files are registered in project.pbxproj
    func testPolicyFilesRegisteredInPbxproj() {
        let pbxContent = findFileContent(["boringNotch.xcodeproj/project.pbxproj"])
        XCTAssertNotNil(pbxContent, "Cannot read project.pbxproj")
        guard let pbxContent = pbxContent else { return }

        XCTAssertTrue(pbxContent.contains("StepPolicyRegistry.swift in Sources"), "Missing StepPolicyRegistry in pbxproj")
        XCTAssertTrue(pbxContent.contains("InspectStepPolicy.swift in Sources"), "Missing InspectStepPolicy in pbxproj")
        XCTAssertTrue(pbxContent.contains("ComposeStepPolicy.swift in Sources"), "Missing ComposeStepPolicy in pbxproj")
        XCTAssertTrue(pbxContent.contains("ValidationPolicyRegistry.swift in Sources"), "Missing ValidationPolicyRegistry in pbxproj")
        XCTAssertTrue(pbxContent.contains("InspectValidationPolicy.swift in Sources"), "Missing InspectValidationPolicy in pbxproj")
        XCTAssertTrue(pbxContent.contains("ComposeValidationPolicy.swift in Sources"), "Missing ComposeValidationPolicy in pbxproj")
    }

    // Assertion 5: Modular Documentation Files exist
    func testModularDocumentationFilesExist() {
        let specExists = fileExistsInAny(["docs/reasoning/INTENT_SPEC.md"])
        let policiesExists = fileExistsInAny(["docs/reasoning/PROMPT_POLICIES.md"])

        XCTAssertTrue(specExists, "Missing docs/reasoning/INTENT_SPEC.md")
        XCTAssertTrue(policiesExists, "Missing docs/reasoning/PROMPT_POLICIES.md")
    }
}
