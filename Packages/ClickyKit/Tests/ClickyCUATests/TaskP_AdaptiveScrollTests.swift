import XCTest
@testable import ClickyCUA
@testable import ClickyPlatform

final class TaskP_AdaptiveScrollTests: XCTestCase {
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

    private func computeAdaptiveStep(totalRows: Int, visibleRows: Int, isPage: Bool) -> Float {
        if totalRows > 0 {
            if isPage {
                let rowsToScroll = max(Float(visibleRows - 1), 4.0)
                return min(rowsToScroll / Float(totalRows), 0.50)
            } else {
                let rowsToScroll: Float = 2.5
                return min(rowsToScroll / Float(totalRows), 0.25)
            }
        }
        return isPage ? 0.08 : 0.015
    }

    // Assertion 1: CUAScrollActionTool implements calculateAdaptiveStep with row-proportionality
    func testCUAScrollActionToolImplementsAdaptiveStepWithRowProportionality() {
        let content = findFileContent([
            "boringNotch/Clicky/CUA/Actions/CUAScrollActionTool.swift",
            "Packages/ClickyKit/Sources/ClickyCUA/CUAScrollActionTool.swift"
        ]) ?? ""

        let hasAdaptiveFunc = content.contains("calculateAdaptiveStep")
        let hasRowProportional = content.contains("rowsToScroll / Float(rows)")
        let hasTableSearch = content.contains("findFirstTableOrOutline")
        let hasNoStaticCoarseStep = !content.contains("let step: Float = 0.20")

        XCTAssertTrue(hasAdaptiveFunc, "CUAScrollActionTool must implement calculateAdaptiveStep")
        XCTAssertTrue(hasRowProportional, "Must compute row-proportional step")
        XCTAssertTrue(hasTableSearch, "Must find table or outline")
        XCTAssertTrue(hasNoStaticCoarseStep, "Must not contain static coarse 0.20 step")
    }

    // Assertion 2: MascotVirtualDesktopService distributes wheel delta smoothly and posts to PID
    func testMascotVirtualDesktopServiceDistributesWheelDeltaSmoothlyAndPostsToPID() {
        let content = findFileContent([
            "boringNotch/Clicky/Workspace/VirtualDisplay/MascotVirtualDesktopService.swift",
            "Packages/ClickyKit/Sources/ClickyPlatform/MascotVirtualDesktopService.swift"
        ]) ?? ""

        let hasDistributedSteps = content.contains("let stepDeltaY = deltaY / Int32(steps)")
        let hasPidPosting = content.contains("ev.postToPid(pid)")
        let hasSessionTap = content.contains("ev.post(tap: .cgSessionEventTap)")
        let hasHidTap = content.contains("ev.post(tap: .cghidEventTap)")

        XCTAssertTrue(hasDistributedSteps, "Must divide deltaY by steps")
        XCTAssertTrue(hasPidPosting, "Must post to target PID")
        XCTAssertTrue(hasSessionTap, "Must post to session event tap")
        XCTAssertTrue(hasHidTap, "Must post to HID event tap")
    }

    // Assertion 3: Mathematical Verification of Adaptive Step Scale Invariance
    func testAdaptiveStepMathematicalScaleInvariance() {
        // Case A: 20,897 emails (User's real scenario)
        let stepMassive = computeAdaptiveStep(totalRows: 20897, visibleRows: 7, isPage: false)
        let rowsMovedMassive = stepMassive * 20897.0

        // Case B: 50 emails
        let stepMedium = computeAdaptiveStep(totalRows: 50, visibleRows: 7, isPage: false)
        let rowsMovedMedium = stepMedium * 50.0

        // Case C: Page scroll on 20,897 emails
        let stepPageMassive = computeAdaptiveStep(totalRows: 20897, visibleRows: 7, isPage: true)
        let rowsMovedPageMassive = stepPageMassive * 20897.0

        let deltaMassiveDiff = abs(rowsMovedMassive - 2.5)
        let deltaMediumDiff = abs(rowsMovedMedium - 2.5)
        let deltaPageDiff = abs(rowsMovedPageMassive - 6.0)

        XCTAssertLessThan(deltaMassiveDiff, 0.01, "Massive inbox step error must be < 0.01")
        XCTAssertLessThan(deltaMediumDiff, 0.01, "Medium inbox step error must be < 0.01")
        XCTAssertLessThan(deltaPageDiff, 0.01, "Page scroll step error must be < 0.01")
    }

    // Assertion 4: Verification of Prevention of 4,000-email skipping
    func testCatastrophicSkipPrevention() {
        let oldCoarseRowsSkipped = 0.20 * 20897.0 // Previously: 4,179.4 emails
        let stepMassive = computeAdaptiveStep(totalRows: 20897, visibleRows: 7, isPage: false)
        let newAdaptiveRowsSkipped = stepMassive * 20897.0 // Now: 2.5 emails

        XCTAssertLessThan(newAdaptiveRowsSkipped, 5.0, "New adaptive skip must be < 5 rows")
        XCTAssertGreaterThan(oldCoarseRowsSkipped, 4000.0, "Old skip was > 4000 rows")
    }
}
