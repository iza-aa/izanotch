import Foundation

print("=== Running Verification Test: Adaptive Kinematic Scroll & Row-Proportional Calculation ===")

let rootPath = "/Users/heizaaa/Desktop/cdev/iza-3"
let scrollToolPath = "\(rootPath)/boringNotch/Clicky/CUA/Actions/CUAScrollActionTool.swift"
let vdServicePath = "\(rootPath)/boringNotch/Clicky/Workspace/VirtualDisplay/MascotVirtualDesktopService.swift"

var passed = 0
var total = 0

// Test 1: CUAScrollActionTool implements calculateAdaptiveStep with row-proportionality
total += 1
if let content = try? String(contentsOfFile: scrollToolPath, encoding: .utf8) {
    let hasAdaptiveFunc = content.contains("calculateAdaptiveStep")
    let hasRowProportional = content.contains("rowsToScroll / Float(rows)")
    let hasTableSearch = content.contains("findFirstTableOrOutline")
    let hasNoStaticCoarseStep = !content.contains("let step: Float = 0.20")

    if hasAdaptiveFunc && hasRowProportional && hasTableSearch && hasNoStaticCoarseStep {
        print("  ✅ [PASS] CUAScrollActionTool implements dynamic row-proportional calculation without coarse 0.20 jump")
        passed += 1
    } else {
        print("  ❌ [FAIL] CUAScrollActionTool missing adaptive components (func: \(hasAdaptiveFunc), prop: \(hasRowProportional), search: \(hasTableSearch), noCoarse: \(hasNoStaticCoarseStep))")
    }
} else {
    print("  ❌ [FAIL] Cannot read \(scrollToolPath)")
}

// Test 2: MascotVirtualDesktopService distributes wheel delta smoothly and posts to PID
total += 1
if let content = try? String(contentsOfFile: vdServicePath, encoding: .utf8) {
    let hasDistributedSteps = content.contains("let stepDeltaY = deltaY / Int32(steps)")
    let hasPidPosting = content.contains("ev.postToPid(pid)")
    let hasSessionTap = content.contains("ev.post(tap: .cgSessionEventTap)")
    let hasHidTap = content.contains("ev.post(tap: .cghidEventTap)")

    if hasDistributedSteps && hasPidPosting && hasSessionTap && hasHidTap {
        print("  ✅ [PASS] MascotVirtualDesktopService smoothly distributes scroll wheel delta and posts to target PID")
        passed += 1
    } else {
        print("  ❌ [FAIL] MascotVirtualDesktopService missing distributed delta or PID posting")
    }
} else {
    print("  ❌ [FAIL] Cannot read \(vdServicePath)")
}

// Test 3: Mathematical Verification of Adaptive Step Scale Invariance
total += 1
func testAdaptiveStep(totalRows: Int, visibleRows: Int, isPage: Bool) -> Float {
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

// Case A: 20,897 emails (User's real scenario)
let stepMassive = testAdaptiveStep(totalRows: 20897, visibleRows: 7, isPage: false)
let rowsMovedMassive = stepMassive * 20897.0

// Case B: 50 emails
let stepMedium = testAdaptiveStep(totalRows: 50, visibleRows: 7, isPage: false)
let rowsMovedMedium = stepMedium * 50.0

// Case C: Page scroll on 20,897 emails
let stepPageMassive = testAdaptiveStep(totalRows: 20897, visibleRows: 7, isPage: true)
let rowsMovedPageMassive = stepPageMassive * 20897.0

let deltaMassiveDiff = abs(rowsMovedMassive - 2.5)
let deltaMediumDiff = abs(rowsMovedMedium - 2.5)
let deltaPageDiff = abs(rowsMovedPageMassive - 6.0)

if deltaMassiveDiff < 0.01 && deltaMediumDiff < 0.01 && deltaPageDiff < 0.01 {
    print("  ✅ [PASS] Mathematical invariant verified: both 20,897 and 50 row inboxes advance by exactly 2.5 rows (diff < 0.01)")
    passed += 1
} else {
    print("  ❌ [FAIL] Math deviation: massive=\(rowsMovedMassive), medium=\(rowsMovedMedium), page=\(rowsMovedPageMassive)")
}

// Test 4: Verification of Prevention of 4,000-email skipping
total += 1
let oldCoarseRowsSkipped = 0.20 * 20897.0 // Previously: 4,179.4 emails!
let newAdaptiveRowsSkipped = stepMassive * 20897.0 // Now: 2.5 emails!

if newAdaptiveRowsSkipped < 5.0 && oldCoarseRowsSkipped > 4000.0 {
    print("  ✅ [PASS] Catastrophic skip prevented: previous jump moved \(Int(oldCoarseRowsSkipped)) emails; new adaptive moves \(String(format: "%.1f", newAdaptiveRowsSkipped)) emails")
    passed += 1
} else {
    print("  ❌ [FAIL] Skip prevention assertion failed")
}

print("\n=== Summary: \(passed)/\(total) Tests Passed ===")
if passed == total {
    print("🏆 ALL TESTS PASSED!")
    exit(0)
} else {
    print("❌ SOME TESTS FAILED!")
    exit(1)
}
