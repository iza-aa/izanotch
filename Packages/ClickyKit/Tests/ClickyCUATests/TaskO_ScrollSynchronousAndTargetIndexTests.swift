import XCTest
@testable import ClickyCUA
@testable import ClickyPlatform
@testable import ClickyReasoning
@testable import ClickyAgent

final class TaskO_ScrollSynchronousAndTargetIndexTests: XCTestCase {
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

    // Assertion 1: CUAScrollActionTool implements dual-layer scroll via AXScrollArea & AXScrollBar
    func testCUAScrollActionToolDualLayerScroll() {
        let content = findFileContent([
            "boringNotch/Clicky/CUA/Actions/CUAScrollActionTool.swift",
            "Packages/ClickyKit/Sources/ClickyCUA/CUAScrollActionTool.swift"
        ]) ?? ""

        let hasScrollArea = content.contains("AXScrollArea")
        let hasScrollBar = content.contains("AXScrollBar")
        let hasIncrement = content.contains("AXIncrement") && content.contains("AXDecrement")
        let hasValue = content.contains("kAXValueAttribute")

        XCTAssertTrue(hasScrollArea, "CUAScrollActionTool must reference AXScrollArea")
        XCTAssertTrue(hasScrollBar, "CUAScrollActionTool must reference AXScrollBar")
        XCTAssertTrue(hasIncrement, "CUAScrollActionTool must support AXIncrement/AXDecrement")
        XCTAssertTrue(hasValue, "CUAScrollActionTool must set kAXValueAttribute")
    }

    // Assertion 2: MascotVirtualDesktopService posts pixel scroll events to session and HID taps
    func testMascotVirtualDesktopServicePixelScrollEvents() {
        let content = findFileContent([
            "boringNotch/Clicky/Workspace/VirtualDisplay/MascotVirtualDesktopService.swift",
            "Packages/ClickyKit/Sources/ClickyPlatform/MascotVirtualDesktopService.swift"
        ]) ?? ""

        let hasSessionTap = content.contains("cgSessionEventTap")
        let hasHidTap = content.contains("cghidEventTap")
        let hasPixelUnits = content.contains("units: .pixel")

        XCTAssertTrue(hasSessionTap, "Must post to cgSessionEventTap")
        XCTAssertTrue(hasHidTap, "Must post to cghidEventTap")
        XCTAssertTrue(hasPixelUnits, "Must specify units: .pixel")
    }

    // Assertion 3: CompanionWindowStreamService writes snapshot PNG synchronously
    func testCompanionWindowStreamServiceSynchronousPNGWrite() {
        let content = findFileContent([
            "boringNotch/Clicky/Workspace/Streaming/CompanionWindowStreamService.swift",
            "Packages/ClickyKit/Sources/ClickyPlatform/CompanionWindowStreamService.swift"
        ]) ?? ""

        let hasAsyncPngWrite = content.contains("DispatchQueue.global(qos: .utility).async {\n                    if let cgImage = sckImage") || content.contains("DispatchQueue.global(qos: .utility).async {\n                    let bitmapRep = NSBitmapImageRep(cgImage: cgImage)")
        let hasSyncPngWrite = content.contains("pngData.write(to: URL(fileURLWithPath: targetFilePath), options: .atomic)")

        XCTAssertFalse(hasAsyncPngWrite, "CompanionWindowStreamService must not write PNG asynchronously")
        XCTAssertTrue(hasSyncPngWrite, "CompanionWindowStreamService must write PNG data synchronously with .atomic")
    }

    // Assertion 4: TaskStepPlanner strictly enforces scroll when target index is not in listItems
    func testTaskStepPlannerScrollWhenTargetIndexNotPresent() {
        let rawContent = findFileContent([
            "boringNotch/Clicky/Reasoning/Planner/TaskStepPlanner.swift",
            "Packages/ClickyKit/Sources/ClickyReasoning/TaskStepPlanner.swift"
        ]) ?? ""
        let policyContent = findFileContent([
            "boringNotch/Clicky/Reasoning/Planner/Policies/InspectStepPolicy.swift",
            "Packages/ClickyKit/Sources/ClickyReasoning/InspectStepPolicy.swift"
        ]) ?? ""
        let content = rawContent + "\n" + policyContent

        let hasTargetIndexRule = content.contains("Check if an entry with that exact index exists in listItems")
        let hasNoPrematureClick = content.contains("NEVER plan actionType: \"click\" on an item index that is not present in listItems")

        XCTAssertTrue(hasTargetIndexRule, "Must verify if entry exists in listItems")
        XCTAssertTrue(hasNoPrematureClick, "Must forbid clicking items not in listItems")
    }

    // Assertion 5: TaskEgressValidator enforces Target Index Presence & Reading Pane Prerequisite
    func testTaskEgressValidatorPresenceCheckAndReadingPanePrereq() {
        let rawContent = findFileContent([
            "boringNotch/Clicky/Reasoning/Validator/TaskEgressValidator.swift",
            "Packages/ClickyKit/Sources/ClickyReasoning/TaskEgressValidator.swift"
        ]) ?? ""
        let policyContent = findFileContent([
            "boringNotch/Clicky/Reasoning/Validator/Policies/InspectValidationPolicy.swift",
            "Packages/ClickyKit/Sources/ClickyReasoning/InspectValidationPolicy.swift"
        ]) ?? ""
        let content = rawContent + "\n" + policyContent

        let hasPresenceCheck = content.contains("Target Index Presence Check")
        let hasReadingPanePrereq = content.contains("Reading Pane Prerequisite")
        let hasNoItem1Hallucination = content.contains("NEVER hallucinate or report text from an unrelated item (such as item 1)")

        XCTAssertTrue(hasPresenceCheck, "Must contain Target Index Presence Check")
        XCTAssertTrue(hasReadingPanePrereq, "Must contain Reading Pane Prerequisite")
        XCTAssertTrue(hasNoItem1Hallucination, "Must forbid hallucinating text from unrelated items")
    }

    // Assertion 6: CompanionVMAgentLoop has targetIndexNotReached guard preventing premature exit
    func testCompanionVMAgentLoopTargetIndexNotReachedGuard() {
        let content = findFileContent([
            "boringNotch/Clicky/CUA/Loop/CompanionVMAgentLoop.swift",
            "Packages/ClickyKit/Sources/ClickyAgent/CompanionVMAgentLoop.swift"
        ]) ?? ""

        let hasTargetGuard = content.contains("targetIndexNotReached") && content.contains("hasClickedTarget")
        XCTAssertTrue(hasTargetGuard, "CompanionVMAgentLoop must enforce targetIndexNotReached and hasClickedTarget guards")
    }

    // Assertion 7: Verify izaNotch is running
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
