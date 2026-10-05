import Foundation

// MARK: - Test Revisions F-18: Solid Red Notification Dot with #FF3C2F & Dark Border #1C1C1C
print("=== Running Test Revisions F-18 ===")

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

// Test 1: Uses exact extracted Red Hex #FF3C2F
let hasRedHex = content.contains("FF3C2F")
assertTest(hasRedHex, "UnreadNotificationCircleBadge uses exact sampled red #FF3C2F")

// Test 2: Uses exact extracted Border Hex #1C1C1C
let hasBorderHex = content.contains("1C1C1C")
assertTest(hasBorderHex, "UnreadNotificationCircleBadge uses exact sampled dark border #1C1C1C")

// Test 3: Badge is larger (inner 12-14px, outer 16-18px)
let hasLargerBadge = (content.contains("width: 12") || content.contains("width: 13") || content.contains("width: 14")) &&
                     (content.contains("width: 16") || content.contains("width: 17") || content.contains("width: 18"))
assertTest(hasLargerBadge, "UnreadNotificationCircleBadge has larger diameter matching user mockup")

// Test 4: TopTrailing alignment preserved
let hasTopTrailing = content.contains("ZStack(alignment: .topTrailing)")
assertTest(hasTopTrailing, "Badge is pinned to top-right (topTrailing)")

print("=== Results: \(testsPassed)/\(totalTests) tests passed ===")
if testsPassed == totalTests {
    print("ALL TESTS PASSED")
    exit(0)
} else {
    print("SOME TESTS FAILED (Expected before implementation)")
    exit(1)
}
