import Foundation

// TDD Verification Test for Milestone 179 (Revisi F-12: Dynamic Contextual Welcome State, Zero Badge, Zero Chips)

func testRevisionsF12() {
    print("=== START TEST REVISIONS F-12 ===")

    let rootPath = "/Users/heizaaa/Desktop/cdev/iza-3"
    let homeSpaceViewPath = "\(rootPath)/boringNotch/Clicky/HomeSpace/HomeSpaceRootView.swift"
    guard let content = try? String(contentsOfFile: homeSpaceViewPath, encoding: .utf8) else {
        fatalError("Failed to read HomeSpaceRootView.swift")
    }

    // 1. Verify "• READY" or "CLICKY • READY" badge is deleted from welcome state
    assert(!content.contains("Text(\"READY\")"), "FAIL: Status pill badge 'READY' still exists")
    assert(!content.contains("Text(companion.activeBuddy.name.uppercased())"), "FAIL: Uppercased companion name pill still exists")
    print("✓ Test 1: Status pill badge ('CLICKY • READY') completely deleted")

    // 2. Verify prompt chips ('Screen Context', 'Summarize Docs', 'Futures Analysis') are deleted
    assert(!content.contains("Text(\"Screen Context\")"), "FAIL: 'Screen Context' chip still exists")
    assert(!content.contains("Text(\"Summarize Docs\")"), "FAIL: 'Summarize Docs' chip still exists")
    assert(!content.contains("Text(\"Futures Analysis\")"), "FAIL: 'Futures Analysis' chip still exists")
    print("✓ Test 2: Prompt chips ('Screen Context', 'Summarize Docs', 'Futures Analysis') completely deleted")

    // 3. Verify dynamic welcome title and subtitle helper properties exist
    assert(content.contains("dynamicWelcomeTitle"), "FAIL: dynamicWelcomeTitle property missing")
    assert(content.contains("dynamicWelcomeSubtitle"), "FAIL: dynamicWelcomeSubtitle property missing")
    print("✓ Test 3: Dynamic contextual welcome title & subtitle implemented")

    print("=== ALL REVISIONS F-12 TESTS PASSED (100%) ===")
}

testRevisionsF12()
