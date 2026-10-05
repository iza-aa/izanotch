import Foundation

// MARK: - Test Revisions F-17: Small Borderless Blue Notification Dot on Top-Right
print("=== Running Test Revisions F-17 ===")

var testsPassed = 0
var totalTests = 0

func assertTest(_ condition: Bool, _ name: String) {
    totalTests += 1
    if condition {
        testsPassed += 1
        print("  ✅ [PASS] \(name)")
    } else {
        print("  ❌ [FAIL] \(name)")
    }
}

let rootDir = "/Users/heizaaa/Desktop/cdev/iza-3"
let railViewPath = "\(rootDir)/boringNotch/Clicky/Rail/FloatingCompanionRailView.swift"

guard let content = try? String(contentsOfFile: railViewPath, encoding: .utf8) else {
    print("❌ Cannot read \(railViewPath)")
    exit(1)
}

// Test 1: Zero blue aura (no blur, no blue shadow in badge)
let hasBlur = content.contains(".blur(radius:")
let hasBlueShadow = content.contains("#0284C7\").opacity(0.6)")
assertTest(!hasBlur && !hasBlueShadow, "No blue aura or blur/shadow in UnreadNotificationCircleBadge")

// Test 2: Zero border (no stroke on badge circle)
let hasStroke = content.contains(".stroke(Color(hex: \"#090D16\"), lineWidth: 2)")
assertTest(!hasStroke, "No dark border ring in UnreadNotificationCircleBadge")

// Test 3: Badge is smaller (diameter <= 10)
let hasSmallFrame = content.contains(".frame(width: 8, height: 8)") ||
                    content.contains(".frame(width: 9, height: 9)") ||
                    content.contains(".frame(width: 10, height: 10)")
assertTest(hasSmallFrame, "UnreadNotificationCircleBadge is compact (8-10px)")

// Test 4: Alignment is topTrailing (kanan atas, bukan kiri)
let hasTopTrailing = content.contains("ZStack(alignment: .topTrailing)")
assertTest(hasTopTrailing, "Badge is aligned to topTrailing (right side, not left)")

print("=== Results: \(testsPassed)/\(totalTests) tests passed ===")
if testsPassed == totalTests {
    print("ALL TESTS PASSED")
    exit(0)
} else {
    print("SOME TESTS FAILED (Expected before implementation)")
    exit(1)
}
