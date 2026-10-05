import Foundation

// MARK: - Test Revisions F-15 (Option 1: Clean Welcome State on Companion Creation & Zero Message Jump)
print("=== Running Test Revisions F-15 ===")

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
let interviewEnginePath = "\(rootDir)/boringNotch/Clicky/Onboarding/CompanionInterviewEngine.swift"
let rootViewPath = "\(rootDir)/boringNotch/Clicky/HomeSpace/HomeSpaceRootView.swift"
let rosterStorePath = "\(rootDir)/boringNotch/Clicky/Roster/CompanionRosterStore.swift"

// Test 1: CompanionInterviewEngine.finalizeAndLaunch sets messages to empty array []
if let content = try? String(contentsOfFile: interviewEnginePath, encoding: .utf8) {
    let hasEmptyMessages = content.contains("messages: []")
    let hasNoInitialGreetingInProfile = !content.contains("messages: [initialGreeting]")
    assertTest(hasEmptyMessages && hasNoInitialGreetingInProfile, "CompanionInterviewEngine initializes new companion with messages: [] (no initial greeting bubble)")
} else {
    assertTest(false, "CompanionInterviewEngine file readable")
}

// Test 2: HomeSpaceRootView message ScrollView VStack has .frame(maxWidth: .infinity, alignment: .leading)
if let content = try? String(contentsOfFile: rootViewPath, encoding: .utf8) {
    let hasVStackLeadingFrame = content.contains(".frame(maxWidth: .infinity, alignment: .leading)")
    assertTest(hasVStackLeadingFrame, "HomeSpaceRootView has .frame(maxWidth: .infinity, alignment: .leading) on chat VStack to eliminate horizontal shifting")
} else {
    assertTest(false, "HomeSpaceRootView file readable")
}

// Test 3: HomeSpaceRootView dynamic welcome titles support inbox / email roles
if let content = try? String(contentsOfFile: rootViewPath, encoding: .utf8) {
    let hasEmailSupport = content.contains("inbox") || content.contains("email")
    assertTest(hasEmailSupport, "HomeSpaceRootView dynamic welcome title supports inbox/email assistant roles")
} else {
    assertTest(false, "HomeSpaceRootView dynamic welcome title check")
}

// Test 4: CompanionRosterStore clears messages for inbox buddy or provides clearMessages
if let content = try? String(contentsOfFile: rosterStorePath, encoding: .utf8) {
    let hasClearMessagesOrReset = content.contains("clearMessages") || content.contains("c.messages = []")
    assertTest(hasClearMessagesOrReset, "CompanionRosterStore supports clearing messages or resetting inbox-buddy")
} else {
    assertTest(false, "CompanionRosterStore readable")
}

print("=== Results: \(testsPassed)/\(totalTests) tests passed ===")
if testsPassed == totalTests {
    print("ALL TESTS PASSED")
    exit(0)
} else {
    print("SOME TESTS FAILED (Expected before edits)")
    exit(1)
}
