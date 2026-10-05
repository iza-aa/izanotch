import Foundation

// MARK: - Test Revisions F-16: Pure Unread Floating Mascot with Blue Notification Circle & Persistent Read State
print("=== Running Test Revisions F-16 ===")

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
let rosterStorePath = "\(rootDir)/boringNotch/Clicky/Roster/CompanionRosterStore.swift"
let railViewPath = "\(rootDir)/boringNotch/Clicky/Rail/FloatingCompanionRailView.swift"
let railWindowPath = "\(rootDir)/boringNotch/Clicky/Rail/FloatingCompanionRailWindow.swift"
let homeSpaceManagerPath = "\(rootDir)/boringNotch/Clicky/HomeSpace/HomeSpaceWindowManager.swift"

// Test 1: CompanionRosterStore has presentedRailCompanionIds and presentCompanionOnRail
if let content = try? String(contentsOfFile: rosterStorePath, encoding: .utf8) {
    let hasPresentedSet = content.contains("presentedRailCompanionIds")
    let hasPresentMethod = content.contains("presentCompanionOnRail")
    assertTest(hasPresentedSet && hasPresentMethod, "CompanionRosterStore tracks presentedRailCompanionIds and has presentCompanionOnRail method")
} else {
    assertTest(false, "CompanionRosterStore readable")
}

// Test 2: CompanionRosterStore.appendMessage triggers unread & rail presentation when chat is closed
if let content = try? String(contentsOfFile: rosterStorePath, encoding: .utf8) {
    let hasChatOpenCheck = content.contains("!isChatOpen") || content.contains("!HomeSpaceWindowManager.shared.isVisible")
    let insertsPresented = content.contains("presentedRailCompanionIds.insert")
    assertTest(hasChatOpenCheck && insertsPresented, "CompanionRosterStore.appendMessage flags unread and inserts to presentedRailCompanionIds when chat is closed")
} else {
    assertTest(false, "CompanionRosterStore appendMessage check")
}

// Test 3: FloatingCompanionRailView eliminates isCompanionWorking from activeMascots
if let content = try? String(contentsOfFile: railViewPath, encoding: .utf8) {
    let noWorkingInActiveMascots = !content.contains("isCompanionWorking(c)")
    let usesPresentedSet = content.contains("presentedRailCompanionIds.contains")
    assertTest(noWorkingInActiveMascots && usesPresentedSet, "FloatingCompanionRailView activeMascots eliminated working state and uses presentedRailCompanionIds")
} else {
    assertTest(false, "FloatingCompanionRailView readable")
}

// Test 4: UnreadNotificationCircleBadge exists and is conditioned on isCompanionUnread
if let content = try? String(contentsOfFile: railViewPath, encoding: .utf8) {
    let hasBadge = content.contains("UnreadNotificationCircleBadge")
    let usesUnreadCondition = content.contains("if isUnread") || content.contains("if isCompanionUnread")
    assertTest(hasBadge && usesUnreadCondition, "UnreadNotificationCircleBadge is defined and conditioned on unread status")
} else {
    assertTest(false, "FloatingCompanionRailView badge check")
}

// Test 5: FloatingCompanionRailWindow uses presentedRailCompanionIds in hitTest
if let content = try? String(contentsOfFile: railWindowPath, encoding: .utf8) {
    let usesPresentedInHitTest = content.contains("presentedRailCompanionIds.contains")
    assertTest(usesPresentedInHitTest, "FloatingCompanionRailWindow uses presentedRailCompanionIds for hit testing")
} else {
    assertTest(false, "FloatingCompanionRailWindow readable")
}

// Test 6: HomeSpaceWindowManager marks active companion as read on show()
if let content = try? String(contentsOfFile: homeSpaceManagerPath, encoding: .utf8) {
    let marksAsRead = content.contains("markAsRead")
    assertTest(marksAsRead, "HomeSpaceWindowManager clears unread status on show()")
} else {
    assertTest(false, "HomeSpaceWindowManager readable")
}

print("=== Results: \(testsPassed)/\(totalTests) tests passed ===")
if testsPassed == totalTests {
    print("ALL TESTS PASSED")
    exit(0)
} else {
    print("SOME TESTS FAILED (Expected before implementation)")
    exit(1)
}
