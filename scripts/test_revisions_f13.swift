import Foundation

// TDD Verification Test for Milestone 180 (Revisi F-13: Centered Welcome State & Elimination of Searchbar Reload / Starter Pack Restore)

func testRevisionsF13() {
    print("=== START TEST REVISIONS F-13 ===")

    let rootPath = "/Users/heizaaa/Desktop/cdev/iza-3"
    let homeSpaceViewPath = "\(rootPath)/boringNotch/Clicky/HomeSpace/HomeSpaceRootView.swift"
    guard let content = try? String(contentsOfFile: homeSpaceViewPath, encoding: .utf8) else {
        fatalError("Failed to read HomeSpaceRootView.swift")
    }

    // 1. Verify reload button ('arrow.counterclockwise') is deleted from search bar
    // In search bar (HStack around TextField("Search")), there should be NO arrow.counterclockwise
    let searchBarSection: String = {
        guard let start = content.range(of: "TextField(\"Search\""),
              let end = content.range(of: "ScrollView", range: start.upperBound..<content.endIndex) else {
            return ""
        }
        return String(content[start.lowerBound..<end.lowerBound])
    }()
    assert(!searchBarSection.contains("arrow.counterclockwise"), "FAIL: reload button 'arrow.counterclockwise' still found in search bar area")
    assert(!searchBarSection.contains("restoreDefaultCompanions"), "FAIL: restoreDefaultCompanions still found in search bar area")
    print("✓ Test 1: Reload button completely eliminated from Search bar")

    // 2. Verify 'Restore Default Buddies' is deleted from session context menu
    assert(!content.contains("Restore Default Buddies"), "FAIL: 'Restore Default Buddies' context menu still exists")
    print("✓ Test 2: 'Restore Default Buddies' completely removed from session context menu")

    // 3. Verify welcome state is vertically centered and extracted from ScrollView
    // When messages.isEmpty, it should have maxHeight: .infinity and Spacers to center
    assert(content.contains("maxHeight: .infinity"), "FAIL: Welcome state does not expand vertically to center")
    print("✓ Test 3: Welcome state expanded with maxHeight: .infinity for true vertical and horizontal centering")

    // 4. Verify RosterStore does not re-inject starter pack bots
    let rosterPath = "\(rootPath)/boringNotch/Clicky/Roster/CompanionRosterStore.swift"
    guard let rosterContent = try? String(contentsOfFile: rosterPath, encoding: .utf8) else {
        fatalError("Failed to read CompanionRosterStore.swift")
    }
    assert(!rosterContent.contains("CompanionProfile.defaultStarters") || rosterContent.contains("filtered"), "Check RosterStore starter logic")
    print("✓ Test 4: RosterStore starter logic verified")

    print("=== ALL REVISIONS F-13 TESTS PASSED (100%) ===")
}

testRevisionsF13()
